import { Global, Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { ThrottlerModule } from '@nestjs/throttler';
import { DB } from '../db/db.module';
import type { Db } from '../db/db';
import { env } from '../config/env';
import { PostgresThrottlerStorage } from './postgres-throttler.storage';
import { RateLimitGuard } from './rate-limit.guard';
import { UserRateLimitGuard } from './user-rate-limit.guard';
import { RateLimitCleanupService } from './rate-limit-cleanup.service';

@Global()
@Module({
  imports: [
    ThrottlerModule.forRootAsync({
      inject: [DB],
      useFactory: (db: Db) => ({
        throttlers: [
          {
            name: 'default',
            ttl: 60_000,
            limit: env.RATE_LIMIT_GLOBAL,
          },
        ],
        storage: new PostgresThrottlerStorage(db),
        errorMessage: 'Too many requests. Please try again later.',
      }),
    }),
  ],
  providers: [
    PostgresThrottlerStorage,
    RateLimitCleanupService,
    RateLimitGuard,
    UserRateLimitGuard,
    { provide: APP_GUARD, useExisting: RateLimitGuard },
  ],
  exports: [PostgresThrottlerStorage, UserRateLimitGuard],
})
export class RateLimitModule {}
