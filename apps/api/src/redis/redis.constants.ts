import type Redis from 'ioredis';

export const REDIS_CLIENT_FACTORY = Symbol('REDIS_CLIENT_FACTORY');

export type RedisClientFactory = (url: string) => Redis;
