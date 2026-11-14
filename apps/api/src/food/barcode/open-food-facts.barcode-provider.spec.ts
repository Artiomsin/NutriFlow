import { describe, expect, it, mock } from 'bun:test';

import {
  BarcodeProviderUnavailableError,
  type BarcodeLookupProvider,
} from './barcode-lookup.provider';
import {
  OpenFoodFactsBarcodeProvider,
  type OpenFoodFactsProviderOptions,
} from './open-food-facts.barcode-provider';

const GTIN14 = '03017620422003';

/** Trimmed from a real v3 response for Nutella. */
const NUTELLA = {
  code: '3017620422003',
  status: 'success',
  product: {
    code: '3017620422003',
    product_name: 'Nutella',
    brands: 'Ferrero, Nutella',
    categories: 'Hazelnut spreads, Confectionary based spreads, fr:Nutella',
    image_front_url: 'https://images.openfoodfacts.org/front.jpg',
    nutriments: {
      'energy-kcal_100g': 539,
      'energy-kj_100g': 2252,
      energy_100g: 2252,
      proteins_100g: 6.3,
      fat_100g: 30.9,
      carbohydrates_100g: 57.5,
    },
  },
};

type FetchInit = Parameters<typeof fetch>[1];

interface RecordedCall {
  readonly url: string;
  readonly init?: FetchInit;
}

function createProvider(
  respond: (url: string) => Promise<Response>,
  overrides: OpenFoodFactsProviderOptions = {},
) {
  const calls: RecordedCall[] = [];
  const fetchImpl = mock(
    async (input: string | URL | Request, init?: FetchInit) => {
      const url = String(input);
      calls.push({ url, init });
      return respond(url);
    },
  );

  const provider = new OpenFoodFactsBarcodeProvider({
    baseUrl: 'https://off.test',
    userAgent: 'NutriFlow/test (test@nutriflow.app)',
    timeoutMs: 1_000,
    requestsPerMinute: 15,
    fetchImpl: fetchImpl as unknown as typeof fetch,
    ...overrides,
  });

  return { provider, calls };
}

function json(body: unknown, status = 200): Promise<Response> {
  return Promise.resolve(
    new Response(JSON.stringify(body), {
      status,
      headers: { 'content-type': 'application/json' },
    }),
  );
}

function asProvider(
  provider: OpenFoodFactsBarcodeProvider,
): BarcodeLookupProvider {
  return provider;
}

describe('OpenFoodFactsBarcodeProvider', () => {
  it('queries the v3 product endpoint with a descriptive User-Agent', async () => {
    const { provider, calls } = createProvider(() => json(NUTELLA));

    await provider.lookup(GTIN14);

    expect(calls).toHaveLength(1);
    expect(calls[0]?.url).toBe(
      `https://off.test/api/v3/product/${GTIN14}.json?fields=code,product_name,product_name_en,generic_name,brands,categories,image_front_url,image_url,nutriments`,
    );
    const headers = calls[0]?.init?.headers as Record<string, string>;
    expect(headers['User-Agent']).toBe('NutriFlow/test (test@nutriflow.app)');
    expect(headers.Accept).toBe('application/json');
  });

  it('maps an OFF product to the provider-independent shape', async () => {
    const { provider } = createProvider(() => json(NUTELLA));

    const product = await provider.lookup(GTIN14);

    expect(product).toEqual({
      name: 'Nutella',
      brand: 'Ferrero',
      categoryName: 'Hazelnut spreads',
      caloriesPer100g: 539,
      proteinPer100g: 6.3,
      fatPer100g: 30.9,
      carbsPer100g: 57.5,
      barcode: '3017620422003',
      imageUrl: 'https://images.openfoodfacts.org/front.jpg',
      source: 'off',
      createdBy: null,
    });
  });

  it('converts kilojoules when kcal is missing', async () => {
    const { provider } = createProvider(() =>
      json({
        status: 'success',
        product: {
          product_name: 'KJ only',
          nutriments: { 'energy-kj_100g': 418.4, proteins_100g: 1 },
        },
      }),
    );

    const product = await provider.lookup(GTIN14);

    expect(product?.caloriesPer100g).toBe(100);
  });

  it('treats 404 as a genuine miss', async () => {
    const { provider } = createProvider(() => json({ status: 'failure' }, 404));

    expect(await provider.lookup(GTIN14)).toBeNull();
    expect(await provider.healthCheck()).toBe(true);
  });

  it('treats a failure status or nameless product as a miss', async () => {
    const { provider } = createProvider(() => json({ status: 'failure' }));

    expect(await provider.lookup(GTIN14)).toBeNull();
  });

  it('ignores products without usable calories', async () => {
    const { provider } = createProvider(() =>
      json({
        status: 'success',
        product: {
          product_name: 'Water',
          nutriments: { 'energy-kcal_100g': 0 },
        },
      }),
    );

    expect(await provider.lookup(GTIN14)).toBeNull();
  });

  it('throws when OFF answers 429 or 5xx', async () => {
    const { provider } = createProvider(() => json({}, 429));

    await expect(provider.lookup(GTIN14)).rejects.toBeInstanceOf(
      BarcodeProviderUnavailableError,
    );
  });

  it('throws when the request fails or times out', async () => {
    const { provider } = createProvider(() =>
      Promise.reject(new DOMException('timed out', 'TimeoutError')),
    );

    await expect(provider.lookup(GTIN14)).rejects.toThrow('timed out');
  });

  it('enforces its own per-minute request budget', async () => {
    const { provider, calls } = createProvider(
      () => json({ status: 'failure' }, 404),
      { requestsPerMinute: 2 },
    );

    await provider.lookup(GTIN14);
    await provider.lookup(GTIN14);
    await expect(provider.lookup(GTIN14)).rejects.toBeInstanceOf(
      BarcodeProviderUnavailableError,
    );

    expect(calls).toHaveLength(2);
  });

  it('opens the circuit after repeated failures and reports unhealthy', async () => {
    const { provider } = createProvider(() => json({}, 500), {
      failureThreshold: 3,
      cooldownMs: 60_000,
    });

    for (let attempt = 0; attempt < 3; attempt += 1) {
      await expect(provider.lookup(GTIN14)).rejects.toBeInstanceOf(
        BarcodeProviderUnavailableError,
      );
    }

    expect(await provider.healthCheck()).toBe(false);
    expect(asProvider(provider).priority).toBe(20);
    expect(asProvider(provider).cacheable).toBe(true);
  });

  it('recovers once the cooldown has elapsed', async () => {
    const { provider } = createProvider(() => json({}, 500), {
      failureThreshold: 1,
      cooldownMs: 0,
    });

    await expect(provider.lookup(GTIN14)).rejects.toBeInstanceOf(
      BarcodeProviderUnavailableError,
    );

    expect(await provider.healthCheck()).toBe(true);
  });
});
