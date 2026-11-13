import { describe, expect, it } from 'bun:test';

import type { RedisService } from '../../redis/redis.service';
import {
  BarcodeLookupProvider,
  type BarcodeProduct,
} from './barcode-lookup.provider';
import { BarcodeLookupService } from './barcode-lookup.service';

const EAN13 = '4006381333931';
const GTIN14 = '04006381333931';

function createRedis() {
  const store = new Map<string, string>();
  const redis = {
    store,
    get: async (key: string) => store.get(key) ?? null,
    set: async (key: string, value: string) => {
      store.set(key, value);
    },
    delete: async (key: string) => {
      store.delete(key);
    },
  };
  return { redis: redis as unknown as RedisService, store };
}

function catalogProduct(
  overrides: Partial<BarcodeProduct> = {},
): BarcodeProduct {
  return {
    id: 'food-1',
    name: 'Catalog Product',
    barcode: EAN13,
    caloriesPer100g: 100,
    source: 'system',
    ...overrides,
  };
}

class StubProvider extends BarcodeLookupProvider {
  readonly calls: Array<{ gtin14: string; userId?: string }> = [];

  constructor(
    readonly name: string,
    readonly priority: number,
    private readonly resolve: (
      gtin14: string,
      userId?: string,
    ) => BarcodeProduct | null,
    override readonly cacheable = true,
    override readonly scope: 'user' | 'global' = 'global',
  ) {
    super();
  }
  async lookup(gtin14: string, userId?: string) {
    this.calls.push({ gtin14, userId });
    return this.resolve(gtin14, userId);
  }
}

class UnavailableProvider extends BarcodeLookupProvider {
  readonly name = 'external';
  readonly priority = 20;
  override readonly cacheable = true;
  override readonly scope: 'user' | 'global';
  calls = 0;

  constructor(
    private readonly healthy = true,
    scope: 'user' | 'global' = 'global',
  ) {
    super();
    this.scope = scope;
  }

  override async healthCheck() {
    return this.healthy;
  }

  async lookup(): Promise<BarcodeProduct | null> {
    this.calls += 1;
    throw new Error('upstream is down');
  }
}

describe('BarcodeLookupService', () => {
  it('rejects an invalid barcode without touching providers', async () => {
    const { redis } = createRedis();
    const provider = new StubProvider('db', 10, () => null);
    const service = new BarcodeLookupService(redis, [provider]);

    const result = await service.lookup('12345', 'user-1');

    expect(result.invalid).toBe(true);
    expect(result.found).toBe(false);
    expect(provider.calls).toHaveLength(0);
  });

  it('canonicalizes the barcode before querying providers', async () => {
    const { redis } = createRedis();
    const provider = new StubProvider('db', 10, () => null);
    const service = new BarcodeLookupService(redis, [provider]);

    await service.lookup('400 6381 333931', 'user-1');

    expect(provider.calls[0]?.gtin14).toBe(GTIN14);
  });

  it('tries providers by priority and stops at the first hit', async () => {
    const { redis } = createRedis();
    const second = new StubProvider('second', 20, () => catalogProduct());
    const first = new StubProvider('first', 10, () => null);
    const service = new BarcodeLookupService(redis, [second, first]);

    const result = await service.lookup(EAN13, 'user-1');

    expect(first.calls).toHaveLength(1);
    expect(second.calls).toHaveLength(1);
    expect(result.provider).toBe('second');
    expect(result.product?.name).toBe('Catalog Product');
  });

  it('serves a cached catalog product to every user', async () => {
    const { redis } = createRedis();
    const provider = new StubProvider('db', 10, () => catalogProduct());
    const service = new BarcodeLookupService(redis, [provider]);

    await service.lookup(EAN13, 'user-1');
    const second = await service.lookup(EAN13, 'user-2');

    expect(provider.calls).toHaveLength(1);
    expect(second.cached).toBe(true);
    expect(second.product?.id).toBe('food-1');
  });

  it('never leaks a personal product into another user cache', async () => {
    const { redis, store } = createRedis();
    const personal = catalogProduct({ source: 'user', createdBy: 'user-1' });
    const provider = new StubProvider('db', 10, (_gtin, userId) =>
      userId === 'user-1' ? personal : null,
    );
    const service = new BarcodeLookupService(redis, [provider]);

    const mine = await service.lookup(EAN13, 'user-1');
    const theirs = await service.lookup(EAN13, 'user-2');

    expect(mine.found).toBe(true);
    expect(theirs.found).toBe(false);
    expect(provider.calls.map((call) => call.userId)).toEqual([
      'user-1',
      'user-2',
    ]);
    expect([...store.keys()].some((key) => key.includes('user-1'))).toBe(true);
  });

  it('caches a miss per user and reuses it', async () => {
    const { redis } = createRedis();
    const provider = new StubProvider('db', 10, () => null);
    const service = new BarcodeLookupService(redis, [provider]);

    const first = await service.lookup(EAN13, 'user-1');
    const second = await service.lookup(EAN13, 'user-1');

    expect(first.found).toBe(false);
    expect(second.cached).toBe(true);
    expect(provider.calls).toHaveLength(1);
  });

  it('passes the user id to providers', async () => {
    const { redis } = createRedis();
    const provider = new StubProvider('db', 10, () => null);
    const service = new BarcodeLookupService(redis, [provider]);

    await service.lookup(EAN13, 'user-42');

    expect(provider.calls[0]).toEqual({ gtin14: GTIN14, userId: 'user-42' });
  });

  it('picks up a catalog product after the cached miss is invalidated', async () => {
    const { redis } = createRedis();
    let sharedProduct: BarcodeProduct | null = null;
    const provider = new StubProvider('db', 10, () => sharedProduct);
    const service = new BarcodeLookupService(redis, [provider]);

    const miss = await service.lookup(EAN13, 'user-1');
    expect(miss.found).toBe(false);

    // The catalog was updated; invalidation is what the import/seed flow does.
    sharedProduct = catalogProduct();
    await service.invalidate(EAN13, 'user-1');

    const result = await service.lookup(EAN13, 'user-1');
    expect(result.found).toBe(true);
    expect(result.product?.id).toBe('food-1');
  });

  it('skips Redis entirely when only cheap providers are registered', async () => {
    const { redis, store } = createRedis();
    const provider = new StubProvider('db', 10, () => catalogProduct(), false);
    const service = new BarcodeLookupService(redis, [provider]);

    await service.lookup(EAN13, 'user-1');
    await service.lookup(EAN13, 'user-1');

    expect(store.size).toBe(0);
    expect(provider.calls).toHaveLength(2);
  });

  it('marks a miss as unavailable when an external provider throws', async () => {
    const { redis, store } = createRedis();
    const local = new StubProvider('db', 10, () => null, false);
    const external = new UnavailableProvider();
    const service = new BarcodeLookupService(redis, [local, external]);

    const result = await service.lookup(EAN13, 'user-1');

    expect(result.found).toBe(false);
    expect(result.unavailable).toBe(true);
    // A provider that could not answer must not produce a cached 404.
    expect(store.size).toBe(0);
  });

  it('retries providers after an unavailable miss instead of serving it', async () => {
    const { redis } = createRedis();
    let fail = true;
    const provider = new StubProvider('db', 10, () => {
      if (fail) {
        throw new Error('down');
      }
      return catalogProduct();
    });
    const service = new BarcodeLookupService(redis, [provider]);

    const first = await service.lookup(EAN13, 'user-1');
    expect(first.unavailable).toBe(true);

    fail = false;
    const second = await service.lookup(EAN13, 'user-1');
    expect(second.found).toBe(true);
    expect(second.cached).toBeUndefined();
    expect(provider.calls).toHaveLength(2);
  });

  it('marks a miss as unavailable when a provider is unhealthy', async () => {
    const { redis } = createRedis();
    const external = new UnavailableProvider(false);
    const service = new BarcodeLookupService(redis, [external]);

    const result = await service.lookup(EAN13, 'user-1');

    expect(result.unavailable).toBe(true);
    expect(external.calls).toBe(0);
  });

  it('skips external providers on a shared miss but still checks personal products', async () => {
    const { redis } = createRedis();
    const local = new StubProvider('db', 10, () => null, true, 'user');
    const external = new StubProvider('off', 20, () => null);
    const service = new BarcodeLookupService(redis, [local, external]);

    // user-1 scans an unknown barcode: both sources are asked once.
    const miss = await service.lookup(EAN13, 'user-1');
    expect(miss.found).toBe(false);
    expect(external.calls).toHaveLength(1);

    // user-2 has no cached entry, but the shared miss already covers every
    // external source: only the user-scoped source runs.
    const second = await service.lookup(EAN13, 'user-2');
    expect(second.cached).toBe(true);
    expect(external.calls).toHaveLength(1);
    expect(local.calls.map((call) => call.userId)).toEqual([
      'user-1',
      'user-2',
    ]);
  });

  it('returns a personal product even when the shared barcode is cached as a miss', async () => {
    const { redis } = createRedis();
    const personal = catalogProduct({
      source: 'user',
      createdBy: 'user-2',
    });
    const local = new StubProvider(
      'db',
      10,
      (_gtin, userId) => (userId === 'user-2' ? personal : null),
      true,
      'user',
    );
    const external = new StubProvider('off', 20, () => null);
    const service = new BarcodeLookupService(redis, [local, external]);

    await service.lookup(EAN13, 'user-1');
    const result = await service.lookup(EAN13, 'user-2');

    expect(result.found).toBe(true);
    expect(result.product?.createdBy).toBe('user-2');
    expect(result.cached).toBeUndefined();
    expect(external.calls).toHaveLength(1);
  });

  it('drops both cache namespaces on invalidate', async () => {
    const { redis, store } = createRedis();
    const provider = new StubProvider('db', 10, () => catalogProduct());
    const service = new BarcodeLookupService(redis, [provider]);

    await service.lookup(EAN13, 'user-1');
    expect(store.size).toBeGreaterThan(0);

    await service.invalidate(EAN13, 'user-1');
    expect(store.size).toBe(0);
  });
});
