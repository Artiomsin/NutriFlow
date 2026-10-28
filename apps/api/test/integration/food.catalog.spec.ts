import { afterAll, beforeAll, describe, expect, it } from 'bun:test';
import { ConfigModule } from '@nestjs/config';
import { ConflictException, NotFoundException } from '@nestjs/common';

import { env } from '../../src/config/env';
import { DbModule } from '../../src/db/db.module';
import { FoodModule } from '../../src/food/food.module';
import { FoodService } from '../../src/food/food.service';
import { createTestModule } from '../utils/app';
import { createTestDb } from '../utils/db';
import type { TestDb, TestTx } from '../utils/db';
import { createCatalogFood, createCategory, createUser } from '../utils/seed';
import type { RedisService } from '../../src/redis/redis.service';

let db: TestDb;
let tx: TestTx;
let rollback: () => Promise<void>;
let service: FoodService;

let usdaFoods: unknown[] = [];
const originalFetch = globalThis.fetch;
let fetchCalls = 0;
const redisCache = new Map<string, string>();
const redisSets: Array<{ key: string; ttlMs: number }> = [];
const fakeRedis = {
  get: async (key: string) => redisCache.get(key) ?? null,
  set: async (key: string, value: string, ttlMs: number) => {
    redisCache.set(key, value);
    redisSets.push({ key, ttlMs });
  },
  delete: async (key: string) => {
    redisCache.delete(key);
  },
};

const defaultFetch = (async () => {
  fetchCalls += 1;
  return new Response(JSON.stringify({ foods: usdaFoods }));
}) as unknown as typeof fetch;

function resetUsdaTestState() {
  usdaFoods = [];
  fetchCalls = 0;
  redisCache.clear();
  redisSets.length = 0;
  globalThis.fetch = defaultFetch;
}

beforeAll(async () => {
  db = createTestDb();
  const opened = await db.openTx();
  tx = opened.tx;
  rollback = opened.rollback;

  const moduleRef = await createTestModule(
    {
      imports: [ConfigModule.forRoot({ isGlobal: true }), DbModule, FoodModule],
    },
    tx,
  );
  service = moduleRef.get(FoodService);

  (service as unknown as { redis: RedisService }).redis =
    fakeRedis as unknown as RedisService;
  resetUsdaTestState();
});

afterAll(async () => {
  globalThis.fetch = originalFetch;
  await rollback();
  await db.close();
});

describe('FoodService.createFood / createCategory', () => {
  it('creates a catalog food with servings', async () => {
    const user = await createUser(tx);
    const food = await service.createFood(user.id, {
      name: 'ZqOats',
      caloriesPer100g: 389,
      proteinPer100g: 17,
      fatPer100g: 7,
      carbsPer100g: 66,
      servings: [{ name: 'bowl', grams: 40 }],
    });

    expect(food.source).toBe('user');
    expect(food.servings).toHaveLength(1);
    expect(food.servings[0]?.grams).toBe(40);
  });

  it('creates a personal category and rejects a duplicate name', async () => {
    const user = await createUser(tx);

    const category = await service.createCategory(user.id, { name: 'ZqDup' });
    expect(category?.createdBy).toBe(user.id);

    // A second call with the same name is a conflict now that categories are
    // scoped per owner instead of being merged into one shared row.
    await expect(
      service.createCategory(user.id, { name: 'ZqDup' }),
    ).rejects.toBeInstanceOf(ConflictException);
  });
});

describe('FoodService.getAll', () => {
  it('returns system and own foods, hiding other users private foods', async () => {
    const user = await createUser(tx);
    const other = await createUser(tx);
    const category = await createCategory(tx, 'ZqCat');
    await createCatalogFood(tx, {
      name: 'ZqVisibleSystem',
      source: 'system',
      categoryId: category.id,
    });
    await createCatalogFood(tx, {
      name: 'ZqVisibleOwn',
      source: 'user',
      createdBy: user.id,
    });
    await createCatalogFood(tx, {
      name: 'ZqHiddenOther',
      source: 'user',
      createdBy: other.id,
    });

    // The shared test database includes the seeded catalog, which currently
    // contains more than 200 foods. Use a limit above the catalog size so this
    // test verifies visibility instead of accidentally testing pagination.
    const groups = await service.getAll(1_000, 0, user.id);
    const names = groups.flatMap((g) => g.foods).map((f) => f.name);

    expect(names).toContain('ZqVisibleSystem');
    expect(names).toContain('ZqVisibleOwn');
    expect(names).not.toContain('ZqHiddenOther');

    const grouped = groups.find((g) => g.name === 'ZqCat');
    expect(grouped?.foods.map((f) => f.name)).toContain('ZqVisibleSystem');
  });
});

describe('FoodService.getById / getByBarcode', () => {
  it('returns a visible food by id and throws for a hidden one', async () => {
    const user = await createUser(tx);
    const other = await createUser(tx);
    const visible = await createCatalogFood(tx, {
      name: 'ZqById',
      source: 'system',
    });
    const hidden = await createCatalogFood(tx, {
      name: 'ZqHiddenById',
      source: 'user',
      createdBy: other.id,
    });

    const found = await service.getById(visible.id, user.id);
    expect(found.id).toBe(visible.id);

    expect(service.getById(hidden.id, user.id)).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it("prefers the user's own product for a shared barcode", async () => {
    const user = await createUser(tx);
    await createCatalogFood(tx, {
      name: 'ZqCatalogBarcode',
      source: 'system',
      barcode: 'ZQ111',
    });
    const own = await createCatalogFood(tx, {
      name: 'ZqOwnBarcode',
      source: 'user',
      createdBy: user.id,
      barcode: 'ZQ111',
    });

    const found = await service.getByBarcode('ZQ111', user.id);
    expect(found?.id).toBe(own.id);

    expect(await service.getByBarcode('ZQNONE', user.id)).toBeNull();
  });
});

describe('FoodService.trackSelection / getPopular', () => {
  it('increments the frequency and throws for a hidden food', async () => {
    const user = await createUser(tx);
    const other = await createUser(tx);
    const food = await createCatalogFood(tx, {
      name: 'ZqTrack',
      source: 'system',
    });
    const hidden = await createCatalogFood(tx, {
      name: 'ZqTrackHidden',
      source: 'user',
      createdBy: other.id,
    });

    await service.trackSelection(user.id, food.id);
    await service.trackSelection(user.id, food.id);

    const popular = await service.getPopular(user.id);
    expect(popular.find((f) => f.id === food.id)).toBeDefined();

    expect(service.trackSelection(user.id, hidden.id)).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('orders popular foods by frequency', async () => {
    const user = await createUser(tx);
    const low = await createCatalogFood(tx, {
      name: 'ZqPopularLow',
      source: 'system',
    });
    const high = await createCatalogFood(tx, {
      name: 'ZqPopularHigh',
      source: 'system',
    });

    await service.trackSelection(user.id, low.id);
    await service.trackSelection(user.id, high.id);
    await service.trackSelection(user.id, high.id);
    await service.trackSelection(user.id, high.id);

    const popular = await service.getPopular(user.id);
    expect(popular.map((f) => f.id)).toEqual([high.id, low.id]);
  });
});

describe('FoodService.search', () => {
  it('extracts a suggested weight and unit from the query', async () => {
    const user = await createUser(tx);
    const byGram = await service.search(
      { q: 'zqchicken 250g', limit: 20, offset: 0 },
      user.id,
    );
    expect(byGram.suggestedGrams).toBe(250);
    expect(byGram.suggestedUnit).toBe('g');

    const byKilo = await service.search(
      { q: 'zqbeef 1.5kg', limit: 20, offset: 0 },
      user.id,
    );
    expect(byKilo.suggestedGrams).toBe(1500);

    const byMilli = await service.search(
      { q: 'zqwater 500 ml', limit: 20, offset: 0 },
      user.id,
    );
    expect(byMilli.suggestedGrams).toBe(500);
    expect(byMilli.suggestedUnit).toBe('ml');
  });

  it('ranks the users own product above the system product', async () => {
    const user = await createUser(tx);
    await createCatalogFood(tx, {
      name: 'zqapple',
      source: 'system',
    });
    await createCatalogFood(tx, {
      name: 'zqapplesauce',
      source: 'user',
      createdBy: user.id,
    });

    const result = await service.search(
      { q: 'zqapple', limit: 20, offset: 0 },
      user.id,
    );
    const names = result.foods.map((f) => f.name);
    expect(names.indexOf('zqapplesauce')).toBeLessThan(
      names.indexOf('zqapple'),
    );
  });

  it('paginates with total and hasMore', async () => {
    const user = await createUser(tx);
    for (const name of ['zqberry1', 'zqberry2', 'zqberry3']) {
      await createCatalogFood(tx, { name, source: 'system' });
    }

    const first = await service.search(
      { q: 'zqberry', limit: 2, offset: 0 },
      user.id,
    );
    expect(first.total).toBe(3);
    expect(first.foods).toHaveLength(2);
    expect(first.hasMore).toBe(true);

    const second = await service.search(
      { q: 'zqberry', limit: 2, offset: 2 },
      user.id,
    );
    expect(second.foods).toHaveLength(1);
    expect(second.hasMore).toBe(false);
  });

  it('falls back to USDA when local results are few', async () => {
    resetUsdaTestState();
    const user = await createUser(tx);
    usdaFoods = [
      {
        fdcId: 1,
        description: 'ZqUsdaItem',
        foodNutrients: [
          { nutrientId: 1008, value: 123 },
          { nutrientId: 1003, value: 5 },
        ],
        gtinUpc: 'ZQ999',
        brandName: 'Brand',
      },
    ];

    try {
      const result = await service.search(
        { q: 'zqusdaitem', limit: 20, offset: 0 },
        user.id,
      );
      const item = result.foods.find((f) => f.name === 'ZqUsdaItem');
      expect(item).toBeDefined();
      expect(item?.source).toBe('usda_sr');
      expect(item?.caloriesPer100g).toBe(123);
    } finally {
      usdaFoods = [];
    }
  });

  it('serves cached USDA results without making an external request', async () => {
    resetUsdaTestState();
    const user = await createUser(tx);
    const product = {
      id: '',
      name: 'ZqCachedRice',
      brand: null,
      categoryName: null,
      categoryId: null,
      caloriesPer100g: 130,
      proteinPer100g: 2,
      fatPer100g: 0,
      carbsPer100g: 28,
      barcode: null,
      imageUrl: null,
      source: 'usda',
      createdBy: null,
      createdAt: '2026-01-01T00:00:00.000Z',
      updatedAt: '2026-01-01T00:00:00.000Z',
    };
    const prefix = 'nutriflow:usda-search:v1:zqcachedrice:';
    redisCache.set(`${prefix}SR%20Legacy`, JSON.stringify([product]));
    redisCache.set(`${prefix}Branded`, JSON.stringify([]));

    const result = await service.search(
      { q: 'zqcachedrice', limit: 20, offset: 0 },
      user.id,
    );

    expect(result.foods.map((food) => food.name)).toContain('ZqCachedRice');
    expect(fetchCalls).toBe(0);
  });

  it('stores USDA results in Redis after a cache miss', async () => {
    resetUsdaTestState();
    const user = await createUser(tx);
    usdaFoods = [
      {
        fdcId: 2,
        description: 'ZqCacheMiss',
        foodNutrients: [],
      },
    ];

    await service.search({ q: 'zqcachemiss', limit: 20, offset: 0 }, user.id);

    expect(fetchCalls).toBe(2);
    expect(redisSets).toHaveLength(2);
    expect(redisSets.every((entry) => entry.ttlMs === 43_200_000)).toBe(true);
  });

  it('returns local results when USDA exceeds the shared deadline', async () => {
    resetUsdaTestState();
    const user = await createUser(tx);
    await createCatalogFood(tx, { name: 'ZqLocalTimeout', source: 'system' });
    const originalTimeout = env.USDA_SEARCH_TIMEOUT_MS;
    env.USDA_SEARCH_TIMEOUT_MS = 1;
    globalThis.fetch = (async (...args: never[]) =>
      new Promise<Response>((_resolve, reject) => {
        const options = args[1] as { signal?: AbortSignal } | undefined;
        options?.signal?.addEventListener('abort', () =>
          reject(options.signal?.reason),
        );
      })) as unknown as typeof fetch;

    try {
      const result = await service.search(
        { q: 'zqlocaltimeout', limit: 20, offset: 0 },
        user.id,
      );
      expect(result.foods.map((food) => food.name)).toContain('ZqLocalTimeout');
    } finally {
      env.USDA_SEARCH_TIMEOUT_MS = originalTimeout;
      resetUsdaTestState();
    }
  });
});
