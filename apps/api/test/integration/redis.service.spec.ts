import { afterAll, beforeAll, describe, expect, it } from 'bun:test';
import Redis from 'ioredis';

import { env } from '../../src/config/env';
import { RedisService } from '../../src/redis/redis.service';

const service = new RedisService(
  (url) =>
    new Redis(url, {
      connectTimeout: 1_000,
      enableOfflineQueue: false,
      lazyConnect: true,
      maxRetriesPerRequest: 1,
      retryStrategy: () => null,
    }),
);
const key = `nutriflow:test:redis:${crypto.randomUUID()}`;
const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

beforeAll(async () => {
  expect(env.REDIS_URL).toBe('redis://localhost:6379');
  await service.onModuleInit();
});

afterAll(async () => {
  await service.delete(key);
  await service.onModuleDestroy();
});

describe('RedisService (Valkey integration)', () => {
  it('connects to Valkey and verifies PING → PONG', () => {
    expect(service.isReady).toBe(true);
  });

  it('stores, reads, and expires a key', async () => {
    await service.set(key, 'cached-result', 100);
    await expect(service.get(key)).resolves.toBe('cached-result');

    await sleep(150);

    await expect(service.get(key)).resolves.toBeNull();
  });
});
