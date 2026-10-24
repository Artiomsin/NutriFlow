import { afterAll, beforeAll, describe, expect, it } from 'bun:test';
import { createHash, randomUUID } from 'node:crypto';
import Redis from 'ioredis';

import { env } from '../../src/config/env';
import { FoodAnalysisService } from '../../src/food/food-analysis.service';
import type { FoodMatcherService } from '../../src/food/food-matcher.service';
import type { VisionProvider } from '../../src/food/vision/vision.types';
import { RedisService } from '../../src/redis/redis.service';

const redis = new RedisService(
  (url) =>
    new Redis(url, {
      connectTimeout: 1_000,
      enableOfflineQueue: false,
      lazyConnect: true,
      maxRetriesPerRequest: 1,
      retryStrategy: () => null,
    }),
);
const userId = `redis-cache-${randomUUID()}`;
const file = {
  buffer: Buffer.from('not-a-real-image'),
  mimetype: 'image/png',
  originalname: 'meal.png',
  size: 17,
};
const redisKey = `nutriflow:food-analysis:${userId}:${createHash('sha256')
  .update(file.buffer)
  .digest('hex')}`;

const emptyCategoriesDb = {
  select: () => ({
    from: () => ({
      where: () => ({
        orderBy: async () => [],
      }),
    }),
  }),
};

function createService(
  provider: VisionProvider,
  quotaCalls: { value: number },
) {
  const service = new FoodAnalysisService(
    {
      matchItems: async (items: unknown[]) => items,
    } as unknown as FoodMatcherService,
    {
      tryReserve: async () => {
        quotaCalls.value += 1;
        return { id: randomUUID(), reservedAt: new Date() };
      },
      consume: async () => {},
      release: async () => {},
    } as never,
    emptyCategoriesDb as never,
    redis,
  );
  (service as unknown as { providers: VisionProvider[] }).providers = [
    provider,
  ];
  return service;
}

beforeAll(async () => {
  expect(env.REDIS_URL).toBe('redis://localhost:6379');
  await redis.onModuleInit();
});

afterAll(async () => {
  await redis.delete(redisKey);
  await redis.onModuleDestroy();
});

describe('FoodAnalysisService with Valkey', () => {
  it('caches a completed food analysis and serves it to a new service instance', async () => {
    let firstProviderCalls = 0;
    const firstQuotaCalls = { value: 0 };
    const firstService = createService(
      {
        name: 'first-provider',
        analyze: async () => {
          firstProviderCalls += 1;
          return JSON.stringify([
            {
              kind: 'food',
              name: 'Rice',
              grams: 150,
              calories: 195,
              protein: 4,
              fat: 0.5,
              carbs: 42,
              confidence: 0.9,
            },
          ]);
        },
      },
      firstQuotaCalls,
    );
    const firstResult = await firstService.analyzePhoto(userId, file);
    expect(firstProviderCalls).toBe(1);
    expect(firstQuotaCalls.value).toBe(1);
    expect(firstResult[0]).toMatchObject({ name: 'Rice', grams: 150 });

    let secondProviderCalls = 0;
    const secondQuotaCalls = { value: 0 };
    const secondService = createService(
      {
        name: 'second-provider',
        analyze: async () => {
          secondProviderCalls += 1;
          throw new Error('Provider must not be called on a Redis cache hit');
        },
      },
      secondQuotaCalls,
    );
    await expect(secondService.analyzePhoto(userId, file)).resolves.toEqual(
      firstResult,
    );
    expect(secondProviderCalls).toBe(0);
    expect(secondQuotaCalls.value).toBe(0);
  });
});
