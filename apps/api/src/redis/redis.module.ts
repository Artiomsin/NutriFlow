import { Global, Module } from '@nestjs/common';
import Redis from 'ioredis';

import {
  REDIS_CLIENT_FACTORY,
  type RedisClientFactory,
} from './redis.constants';
import { RedisService } from './redis.service';

const createRedisClient: RedisClientFactory = (url) =>
  new Redis(url, {
    connectTimeout: 1_000,
    enableOfflineQueue: false,
    lazyConnect: true,
    maxRetriesPerRequest: 1,
    retryStrategy: () => null,
  });

@Global()
@Module({
  providers: [
    {
      provide: REDIS_CLIENT_FACTORY,
      useValue: createRedisClient,
    },
    RedisService,
  ],
  exports: [RedisService],
})
export class RedisModule {}
