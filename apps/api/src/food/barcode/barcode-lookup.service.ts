import { Injectable, Logger } from '@nestjs/common';
import type { OnModuleInit } from '@nestjs/common';

import { RedisService } from '../../redis/redis.service';
import {
  BarcodeLookupProvider,
  type BarcodeLookupResult,
} from './barcode-lookup.provider';
import { toGtin14 } from './gtin';

const POSITIVE_CACHE_TTL_MS = 7 * 24 * 60 * 60 * 1000; // 7 days
const NEGATIVE_CACHE_TTL_MS = 24 * 60 * 60 * 1000; // 1 day

/**
 * Cache namespace. Bumped whenever the cached payload shape changes.
 * `v2` introduced per-user scoping because personal products must never leak
 * between users through a shared cache entry.
 */
const CACHE_PREFIX = 'nutriflow:barcode:v2';

/** Rate limit scope for barcode lookups. */
export const BARCODE_RATE_LIMIT_SCOPE = 'barcode';

interface CacheKeys {
  /** Shared catalog results; safe for every user. */
  readonly shared: string;
  /** User-owned results and negatives; undefined for anonymous callers. */
  readonly user?: string;
}

/**
 * Orchestrates barcode providers.
 *
 * Lookup order:
 *   1. user-scoped cache (their own products / previous negative)
 *   2. shared catalog cache
 *   3. providers, ordered by `priority` (own database first, external APIs
 *      later once they are registered)
 *
 * Adding a provider is a one-line change in `BarcodeModule`: implement
 * `BarcodeLookupProvider` and add it to the factory list.
 */
@Injectable()
export class BarcodeLookupService implements OnModuleInit {
  private readonly logger = new Logger(BarcodeLookupService.name);
  private readonly providers: BarcodeLookupProvider[];
  private readonly userScopedProviders: BarcodeLookupProvider[];
  private readonly cacheEnabled: boolean;

  constructor(
    private readonly redis: RedisService,
    providers: BarcodeLookupProvider[],
  ) {
    // Providers are sorted by priority once at construction.
    this.providers = [...providers].sort((a, b) => a.priority - b.priority);
    this.userScopedProviders = this.providers.filter(
      (provider) => provider.scope === 'user',
    );
    this.cacheEnabled = this.providers.some((provider) => provider.cacheable);
  }

  onModuleInit(): void {
    this.logger.log(
      `Barcode providers registered: ${this.providers
        .map((p) => `${p.name}(priority=${p.priority})`)
        .join(', ')}`,
    );

    if (!this.cacheEnabled) {
      this.logger.log(
        'Barcode cache is off: no cacheable provider registered (local database lookups are cheap enough)',
      );
    }
  }

  /**
   * Looks up a product by a raw barcode string.
   * Normalizes it to GTIN-14, checks the cache, then iterates providers.
   */
  async lookup(
    rawBarcode: string,
    userId?: string,
  ): Promise<BarcodeLookupResult> {
    const gtin14 = toGtin14(rawBarcode);
    if (!gtin14) {
      return { found: false, provider: 'validation', invalid: true };
    }

    // With only the local database in the chain, a lookup is one indexed
    // query. Redis would add latency, memory and staleness for no gain.
    if (!this.cacheEnabled) {
      return this.lookupLive(gtin14, userId);
    }

    const keys = this.cacheKeys(gtin14, userId);

    // 1. The user's own products (or a previous miss for this user).
    const own = keys.user ? await this.readCache(keys.user) : null;
    if (own?.found) {
      return { ...own, cached: true };
    }

    // 2. The shared catalog. Read even when a personal miss is cached so a
    //    catalog product added later is still discovered.
    const shared = await this.readCache(keys.shared);
    if (shared?.found) {
      return { ...shared, cached: true };
    }

    // A user-scoped miss is authoritative: providers already searched both
    // the shared catalog and this user's products when it was written.
    if (own && !own.found) {
      return { ...own, cached: true };
    }

    // A shared miss covers every shared source (catalog and external APIs).
    // An authenticated caller may still own a product with this barcode, so
    // only user-scoped providers run; external quota is not spent again.
    if (shared && !shared.found) {
      if (!userId) {
        return { ...shared, cached: true };
      }

      const personal = await this.lookupPersonal(gtin14, userId);
      if (personal.found) {
        await this.writeCache(keys, personal);
        return personal;
      }
      if (personal.unavailable) {
        return personal;
      }

      // The user has no such product either: remember that per user so the
      // next scan does not even query the database.
      await this.redis.set(
        keys.user!,
        JSON.stringify(shared),
        NEGATIVE_CACHE_TTL_MS,
      );
      return { ...shared, cached: true };
    }

    const result = await this.lookupLive(gtin14, userId);

    // Never cache "not found" when a provider was unavailable: the product may
    // exist and the next attempt should be allowed to reach that provider.
    if (!result.unavailable) {
      await this.writeCache(keys, result);
    }

    return result;
  }

  /**
   * Drops cached lookups for a barcode. Called after a product is created or
   * changed so a stale miss (or an outdated snapshot) cannot be served.
   */
  async invalidate(rawBarcode: string, userId?: string): Promise<void> {
    if (!this.cacheEnabled) {
      return;
    }

    const gtin14 = toGtin14(rawBarcode);
    if (!gtin14) {
      return;
    }

    const keys = this.cacheKeys(gtin14, userId);
    await Promise.all([
      this.redis.delete(keys.shared),
      keys.user ? this.redis.delete(keys.user) : Promise.resolve(),
    ]);
  }

  /** All registered providers ordered by priority. */
  get registeredProviders(): ReadonlyArray<BarcodeLookupProvider> {
    return this.providers;
  }

  private async lookupLive(
    gtin14: string,
    userId?: string,
  ): Promise<BarcodeLookupResult> {
    return this.lookupProviders(this.providers, gtin14, userId);
  }

  /**
   * Only sources that can return data owned by the caller. Used when a shared
   * cache miss already answered for every global source.
   */
  private async lookupPersonal(
    gtin14: string,
    userId: string,
  ): Promise<BarcodeLookupResult> {
    return this.lookupProviders(this.userScopedProviders, gtin14, userId);
  }

  private async lookupProviders(
    providers: ReadonlyArray<BarcodeLookupProvider>,
    gtin14: string,
    userId?: string,
  ): Promise<BarcodeLookupResult> {
    let unavailable = false;

    for (const provider of providers) {
      try {
        const healthy = await provider.healthCheck();
        if (!healthy) {
          // The source is known to be down. Its product may exist, so the
          // final miss is not authoritative.
          unavailable = true;
          this.logger.warn(
            `Skipping unhealthy barcode provider: ${provider.name}`,
          );
          continue;
        }
      } catch {
        unavailable = true;
        this.logger.warn(
          `Health check failed for barcode provider: ${provider.name}`,
        );
        continue;
      }

      try {
        const product = await provider.lookup(gtin14, userId);
        if (product) {
          return { found: true, product, provider: provider.name };
        }
      } catch (error) {
        // One broken provider must not fail the whole scan; the next one gets
        // a chance. The miss is flagged so it is not cached and the caller can
        // answer 503 instead of a misleading 404.
        unavailable = true;
        this.logger.error(
          `Barcode provider ${provider.name} failed for ${gtin14}`,
          error instanceof Error ? error.stack : String(error),
        );
      }
    }

    return {
      found: false,
      provider: 'none',
      ...(unavailable ? { unavailable: true } : {}),
    };
  }

  private cacheKeys(gtin14: string, userId?: string): CacheKeys {
    return {
      shared: `${CACHE_PREFIX}:shared:${gtin14}`,
      ...(userId ? { user: `${CACHE_PREFIX}:user:${userId}:${gtin14}` } : {}),
    };
  }

  private async readCache(key: string): Promise<BarcodeLookupResult | null> {
    const cached = await this.redis.get(key);
    if (!cached) {
      return null;
    }

    try {
      return JSON.parse(cached) as BarcodeLookupResult;
    } catch {
      // Corrupted entry — drop it and fall through to a live lookup.
      await this.redis.delete(key);
      return null;
    }
  }

  private async writeCache(
    keys: CacheKeys,
    result: BarcodeLookupResult,
  ): Promise<void> {
    const ttl = result.found ? POSITIVE_CACHE_TTL_MS : NEGATIVE_CACHE_TTL_MS;
    const payload = JSON.stringify(result);

    if (result.product?.source === 'user') {
      // Personal products are cached per user only.
      if (keys.user) {
        await this.redis.set(keys.user, payload, ttl);
      }
      return;
    }

    await this.redis.set(keys.shared, payload, ttl);
    if (!result.found && keys.user) {
      // A miss for an authenticated user is recorded per user: their own
      // products are invisible to the shared namespace.
      await this.redis.set(keys.user, payload, ttl);
    }
  }
}
