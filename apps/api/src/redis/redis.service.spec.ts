import { afterEach, describe, expect, it, mock } from 'bun:test';
import type Redis from 'ioredis';

import { env } from '../config/env';
import { RedisService } from './redis.service';

const originalRedisUrl = env.REDIS_URL;

afterEach(() => {
  (env as { REDIS_URL: string }).REDIS_URL = originalRedisUrl;
});

function fakeClient(overrides: Record<string, unknown> = {}) {
  return {
    status: 'ready',
    on: mock(() => undefined),
    connect: mock(async () => undefined),
    ping: mock(async () => 'PONG'),
    quit: mock(async () => 'OK'),
    disconnect: mock(() => undefined),
    get: mock(async () => null),
    set: mock(async () => 'OK'),
    del: mock(async () => 1),
    ...overrides,
  };
}

describe('RedisService', () => {
  it('connects and verifies the server with PING → PONG', async () => {
    (env as { REDIS_URL: string }).REDIS_URL = 'redis://cache.internal:6379';
    const client = fakeClient();
    const service = new RedisService(() => client as unknown as Redis);

    await service.onModuleInit();

    expect(client.connect).toHaveBeenCalledTimes(1);
    expect(client.ping).toHaveBeenCalledTimes(1);
    expect(service.isReady).toBe(true);
  });

  it('continues without cache when Redis cannot connect', async () => {
    (env as { REDIS_URL: string }).REDIS_URL = 'redis://cache.internal:6379';
    const client = fakeClient({
      connect: mock(async () => {
        throw new Error('connection refused');
      }),
    });
    const service = new RedisService(() => client as unknown as Redis);

    await service.onModuleInit();

    expect(client.disconnect).toHaveBeenCalledTimes(1);
    expect(service.isReady).toBe(false);
    await expect(service.get('food-analysis:v1:test')).resolves.toBeNull();
  });
});
