import { Logger } from '@nestjs/common';

/** Normalized result returned by any barcode provider. */
export interface BarcodeProduct {
  /** Internal product id when the product exists in our database. */
  readonly id?: string;
  readonly name: string;
  readonly brand?: string | null;
  readonly categoryName?: string | null;
  readonly caloriesPer100g: number;
  readonly proteinPer100g?: number;
  readonly fatPer100g?: number;
  readonly carbsPer100g?: number;
  /** Barcode exactly as stored in the source, for display/debugging. */
  readonly barcode: string;
  readonly imageUrl?: string | null;
  /** 'user' | 'system' | 'usda' | 'off' | 'fatsecret' ... */
  readonly source: string;
  readonly createdBy?: string | null;
  /** Servings attached to the product, if any. */
  readonly servings?: Array<{
    readonly id: string;
    readonly name: string;
    readonly grams: number;
  }>;
}

export interface BarcodeLookupResult {
  readonly found: boolean;
  readonly product?: BarcodeProduct;
  readonly provider: string;
  readonly cached?: boolean;
  /** True when the scanned value is not a valid GTIN. */
  readonly invalid?: boolean;
  /**
   * True when a provider could not be asked (timeout, quota, 5xx).
   *
   * The product may still exist, so this must not be cached as a negative
   * result and should surface as 503 rather than 404.
   */
  readonly unavailable?: boolean;
}

/**
 * Raised by a provider that cannot answer right now.
 *
 * It is deliberately different from returning null: null means "this source
 * does not know the product", while this error means "the answer is unknown".
 */
export class BarcodeProviderUnavailableError extends Error {
  constructor(
    readonly provider: string,
    message: string,
    options?: { cause?: unknown },
  ) {
    super(message, options);
    this.name = 'BarcodeProviderUnavailableError';
  }
}

/** Every barcode source implements this interface. */
export abstract class BarcodeLookupProvider {
  protected readonly logger = new Logger(this.constructor.name);

  /** Human readable name used for metrics and logging. */
  abstract readonly name: string;

  /** Order in which providers are tried (lower = tried first). */
  abstract readonly priority: number;

  /**
   * Whether results from this provider are worth putting into Redis.
   *
   * A provider backed by a local indexed table answers in about a millisecond,
   * so caching it adds a dependency and a second copy of the truth without
   * buying anything. External providers are slow, rate-limited and often paid,
   * so their results must be cached. The lookup service only touches Redis
   * when at least one registered provider sets this flag.
   */
  readonly cacheable: boolean = false;

  /**
   * Which data the provider can return.
   *
   * `global` providers answer the same for everyone (shared catalog, external
   * databases). `user` providers may also return products owned by the caller,
   * so they must still run when a shared cache entry says "not found".
   */
  readonly scope: 'user' | 'global' = 'global';

  /**
   * Looks up a product by canonical GTIN-14.
   *
   * `userId` is required by providers that can return user-owned data and must
   * be ignored by providers backed by a shared catalog.
   * Returns null when this provider does not have the product.
   * Throws only on unexpected infrastructure errors.
   */
  abstract lookup(
    gtin14: string,
    userId?: string,
  ): Promise<BarcodeProduct | null>;

  /** Optional health check. Returns true when the provider is reachable. */
  async healthCheck(): Promise<boolean> {
    return true;
  }
}

/** Base class for providers that need simple error wrapping. */
export abstract class BaseBarcodeLookupProvider extends BarcodeLookupProvider {
  protected async safeLookup(
    gtin14: string,
    action: () => Promise<BarcodeProduct | null>,
  ): Promise<BarcodeProduct | null> {
    try {
      return await action();
    } catch (error) {
      this.logger.error(
        `Barcode lookup failed for ${gtin14} via ${this.name}`,
        error instanceof Error ? error.stack : String(error),
      );
      return null;
    }
  }
}
