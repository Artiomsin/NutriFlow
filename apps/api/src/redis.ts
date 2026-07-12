import Redis from 'ioredis';

const REDIS_URL = process.env.REDIS_URL ?? 'redis://localhost:6379';
const redis = new Redis(REDIS_URL);

export async function cacheGet<T>(key: string): Promise<T | null> {
  try {
    const val = await redis.get(key);
    return val ? JSON.parse(val) as T : null;
  } catch (e) {
    console.error('[Redis] cacheGet error:', e);
    return null;
  }
}

export async function cacheSet(key: string, value: unknown, ttl = 300): Promise<void> {
  try {
    await redis.setex(key, ttl, JSON.stringify(value));
  } catch (e) {
    console.error('[Redis] cacheSet error:', e);
  }
}

export async function cacheDel(key: string): Promise<void> {
  try {
    await redis.del(key);
  } catch (e) {
    console.error('[Redis] cacheDel error:', e);
  }
}

export async function scanKeys(pattern: string): Promise<string[]> {
  const keys: string[] = [];
  let cursor = 0;
  try {
    do {
      const [nextCursor, found] = await redis.scan(cursor, 'MATCH', pattern, 'COUNT', 100);
      cursor = Number(nextCursor);
      keys.push(...found);
    } while (cursor !== 0);
  } catch (e) {
    console.error('[Redis] scanKeys error:', e);
  }
  return keys;
}

export async function cacheDelByPrefix(prefix: string): Promise<void> {
  const keys = await scanKeys(`${prefix}*`);
  if (keys.length) {
    try {
      await redis.del(...keys);
    } catch (e) {
      console.error('[Redis] cacheDelByPrefix error:', e);
    }
  }
}

export async function invalidateAnalyticsCache(userId: string): Promise<void> {
  await cacheDel(`analytics:${userId}:week`);
  await cacheDel(`analytics:${userId}:month`);
  await cacheDelByPrefix(`analytics:${userId}:custom:`);
}

export { redis };
