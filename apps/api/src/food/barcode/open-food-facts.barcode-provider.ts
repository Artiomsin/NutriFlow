import { Injectable } from '@nestjs/common';

import { env } from '../../config/env';
import {
  BarcodeLookupProvider,
  BarcodeProviderUnavailableError,
  type BarcodeProduct,
} from './barcode-lookup.provider';

/**
 * Fields requested from Open Food Facts.
 *
 * The default product payload is several kilobytes of metadata we never show,
 * and the API rejects unknown/misspelled fields, so the list is explicit.
 * `code` is needed because OFF may answer with the canonical product code
 * instead of the padded GTIN-14 that was requested.
 */
const PRODUCT_FIELDS = [
  'code',
  'product_name',
  'product_name_en',
  'generic_name',
  'brands',
  'categories',
  'image_front_url',
  'image_url',
  'nutriments',
].join(',');

const REQUEST_WINDOW_MS = 60_000;
const DEFAULT_FAILURE_THRESHOLD = 5;
const DEFAULT_COOLDOWN_MS = 60_000;

/** OFF reports energy in kJ; nutrition labels use kcal. */
const KILOJOULES_PER_KILOCALORIE = 4.184;

export interface OpenFoodFactsProviderOptions {
  readonly baseUrl?: string;
  readonly userAgent?: string;
  readonly timeoutMs?: number;
  readonly requestsPerMinute?: number;
  readonly failureThreshold?: number;
  readonly cooldownMs?: number;
  /** Overridable for tests so no live request is made. */
  readonly fetchImpl?: typeof fetch;
}

/**
 * Barcode provider backed by the public Open Food Facts database.
 *
 * Reads need no API key. OFF asks for a descriptive `User-Agent` and limits
 * product reads to 15 per minute per server IP, so this provider:
 *   - only runs after the local database missed,
 *   - keeps its own per-minute request budget (shared egress IP),
 *   - lets the lookup service cache hits and misses,
 *   - opens a circuit breaker after repeated failures.
 *
 * `unavailable` is signalled by throwing: a timeout, quota exhaustion or 5xx
 * means "could not check", which must never be cached as "product not found".
 */
@Injectable()
export class OpenFoodFactsBarcodeProvider extends BarcodeLookupProvider {
  readonly name = 'open-food-facts';
  readonly priority = 20;
  /** External, slow and rate-limited: always worth caching. */
  override readonly cacheable = true;

  private readonly baseUrl: string;
  private readonly userAgent: string;
  private readonly timeoutMs: number;
  private readonly requestsPerMinute: number;
  private readonly failureThreshold: number;
  private readonly cooldownMs: number;
  private readonly fetchImpl: typeof fetch;

  /** Timestamps of requests inside the current one-minute window. */
  private readonly requestTimestamps: number[] = [];
  private budgetWarningLogged = false;

  private consecutiveFailures = 0;
  private circuitOpenUntil = 0;

  constructor(options: OpenFoodFactsProviderOptions = {}) {
    super();
    this.baseUrl = (options.baseUrl ?? env.OFF_API_URL).replace(/\/+$/, '');
    this.userAgent = options.userAgent ?? env.OFF_USER_AGENT;
    this.timeoutMs = options.timeoutMs ?? env.OFF_TIMEOUT_MS;
    this.requestsPerMinute =
      options.requestsPerMinute ?? env.OFF_REQUESTS_PER_MINUTE;
    this.failureThreshold =
      options.failureThreshold ?? DEFAULT_FAILURE_THRESHOLD;
    this.cooldownMs = options.cooldownMs ?? DEFAULT_COOLDOWN_MS;
    this.fetchImpl = options.fetchImpl ?? fetch;
  }

  async lookup(gtin14: string): Promise<BarcodeProduct | null> {
    this.assertRequestBudget();

    let response: Response;
    try {
      response = await this.fetchImpl(this.productUrl(gtin14), {
        method: 'GET',
        headers: {
          Accept: 'application/json',
          'User-Agent': this.userAgent,
        },
        signal: AbortSignal.timeout(this.timeoutMs),
      });
    } catch (error) {
      this.recordFailure();
      throw new BarcodeProviderUnavailableError(
        this.name,
        `Open Food Facts request failed for ${gtin14}: ${describe(error)}`,
        { cause: error },
      );
    }

    // OFF answers 404 for a product it does not know. That is a real miss.
    if (response.status === 404) {
      this.recordSuccess();
      return null;
    }

    if (!response.ok) {
      this.recordFailure();
      throw new BarcodeProviderUnavailableError(
        this.name,
        `Open Food Facts responded ${response.status} for ${gtin14}`,
      );
    }

    let body: unknown;
    try {
      body = await response.json();
    } catch (error) {
      this.recordFailure();
      throw new BarcodeProviderUnavailableError(
        this.name,
        `Open Food Facts returned invalid JSON for ${gtin14}`,
        { cause: error },
      );
    }

    this.recordSuccess();

    const payload = asRecord(body);
    const product = payload ? asRecord(payload.product) : null;
    if (!product) {
      // `status: "failure"` and empty products both mean "not in OFF".
      return null;
    }

    return mapProduct(product, gtin14);
  }

  /**
   * The provider is skipped by the lookup service while the breaker is open,
   * which the service reports as `unavailable` rather than `not found`.
   */
  override async healthCheck(): Promise<boolean> {
    if (this.circuitOpenUntil === 0) {
      return true;
    }
    // Expired cooldown: allow one probe request (half-open).
    return Date.now() >= this.circuitOpenUntil;
  }

  private productUrl(gtin14: string): string {
    return `${this.baseUrl}/api/v3/product/${gtin14}.json?fields=${PRODUCT_FIELDS}`;
  }

  /**
   * Sliding one-minute window. Exhausting our own budget is treated as
   * "unavailable" instead of waiting, because a scan must answer quickly; the
   * next attempt either hits the cache or succeeds once the window slides.
   */
  private assertRequestBudget(): void {
    const now = Date.now();
    const windowStart = now - REQUEST_WINDOW_MS;

    while (
      this.requestTimestamps.length > 0 &&
      this.requestTimestamps[0]! < windowStart
    ) {
      this.requestTimestamps.shift();
    }

    if (this.requestTimestamps.length >= this.requestsPerMinute) {
      if (!this.budgetWarningLogged) {
        this.logger.warn(
          `Open Food Facts budget of ${this.requestsPerMinute} requests/minute is exhausted; only cached products are served`,
        );
        this.budgetWarningLogged = true;
      }
      throw new BarcodeProviderUnavailableError(
        this.name,
        'Open Food Facts request budget exhausted',
      );
    }

    this.budgetWarningLogged = false;
    this.requestTimestamps.push(now);
  }

  private recordFailure(): void {
    // A failed half-open probe re-opens the breaker immediately.
    if (this.circuitOpenUntil !== 0 && Date.now() >= this.circuitOpenUntil) {
      this.openCircuit();
      return;
    }

    this.consecutiveFailures += 1;
    if (this.consecutiveFailures >= this.failureThreshold) {
      this.openCircuit();
    }
  }

  private openCircuit(): void {
    this.consecutiveFailures = 0;
    this.circuitOpenUntil = Date.now() + this.cooldownMs;
    this.logger.warn(
      `Open Food Facts failed ${this.failureThreshold} times in a row; pausing lookups for ${Math.round(this.cooldownMs / 1000)}s`,
    );
  }

  private recordSuccess(): void {
    this.consecutiveFailures = 0;
    this.circuitOpenUntil = 0;
  }
}

/** Maps an OFF product payload to our provider-independent shape. */
function mapProduct(
  product: Record<string, unknown>,
  gtin14: string,
): BarcodeProduct | null {
  const name = firstText(
    product.product_name,
    product.product_name_en,
    product.generic_name,
  );
  if (!name) {
    // Without a name the product cannot be shown or saved.
    return null;
  }

  const nutriments = asRecord(product.nutriments) ?? {};
  const calories = caloriesPer100g(nutriments);
  if (calories === null) {
    // Products with no usable energy value would create a 0 kcal entry.
    return null;
  }

  return {
    name,
    brand: firstListItem(product.brands),
    categoryName: firstListItem(product.categories),
    caloriesPer100g: calories,
    proteinPer100g: per100g(nutriments, 'proteins_100g'),
    fatPer100g: per100g(nutriments, 'fat_100g'),
    carbsPer100g: per100g(nutriments, 'carbohydrates_100g'),
    barcode: firstText(product.code) ?? gtin14,
    imageUrl: firstText(product.image_front_url, product.image_url),
    source: 'off',
    createdBy: null,
  };
}

function caloriesPer100g(nutriments: Record<string, unknown>): number | null {
  const kcal = asFiniteNumber(nutriments['energy-kcal_100g']);
  if (kcal !== null && kcal > 0) {
    return roundTo1(kcal);
  }

  // Fall back to kilojoules: `energy-kj_100g`, or `energy_100g` (also kJ).
  const kilojoules = numberOrNull(
    nutriments['energy-kj_100g'],
    nutriments['energy_100g'],
  );
  if (kilojoules === null || kilojoules <= 0) {
    return null;
  }

  return roundTo1(kilojoules / KILOJOULES_PER_KILOCALORIE);
}

/** OFF uses -1, '' or null for unknown nutrient values. */
function per100g(
  nutriments: Record<string, unknown>,
  key: string,
): number | undefined {
  const value = asFiniteNumber(nutriments[key]);
  if (value === null || value < 0) {
    return undefined;
  }
  return roundTo1(value);
}

function roundTo1(value: number): number {
  return Math.round(value * 10) / 10;
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;
}

function asFiniteNumber(value: unknown): number | null {
  if (typeof value === 'number') {
    return Number.isFinite(value) ? value : null;
  }
  if (typeof value === 'string' && value.trim() !== '') {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function numberOrNull(...values: unknown[]): number | null {
  for (const value of values) {
    const parsed = asFiniteNumber(value);
    if (parsed !== null) {
      return parsed;
    }
  }
  return null;
}

function asString(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }
  const trimmed = value.trim();
  return trimmed === '' ? null : trimmed;
}

function firstText(...values: unknown[]): string | null {
  for (const value of values) {
    const text = asString(value);
    if (text) {
      return text;
    }
  }
  return null;
}

/**
 * Takes the first entry of an OFF comma-separated list and strips its
 * language prefix (`fr:Nutella` -> `Nutella`).
 */
function firstListItem(value: unknown): string | null {
  const text = asString(value);
  const first = text?.split(',')[0]?.trim();
  if (!first) {
    return null;
  }
  return first.replace(/^[a-z]{2}:/i, '').trim() || null;
}

function describe(error: unknown): string {
  if (error instanceof Error) {
    return error.name === 'TimeoutError' ? 'request timed out' : error.message;
  }
  return String(error);
}
