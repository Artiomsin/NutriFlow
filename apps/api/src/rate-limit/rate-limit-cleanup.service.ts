import { Inject, Injectable } from '@nestjs/common';
import type { OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { sql } from 'drizzle-orm';
import type { Db } from '../db/db';
import { DB } from '../db/db.module';

const CLEANUP_INTERVAL_MS = 60 * 60 * 1_000;
/** Removes data that can no longer affect a request limit. */
@Injectable()
export class RateLimitCleanupService implements OnModuleInit, OnModuleDestroy {
  private interval?: ReturnType<typeof setInterval>;

  constructor(@Inject(DB) private readonly db: Db) {}

  onModuleInit() {
    this.interval = setInterval(() => void this.cleanup(), CLEANUP_INTERVAL_MS);
    this.interval.unref();
  }

  onModuleDestroy() {
    if (this.interval) clearInterval(this.interval);
  }

  private async cleanup() {
    try {
      await this.db.execute(sql`
        DELETE FROM app.rate_limits
        WHERE expires_at < now()
      `);
      await this.db.execute(sql`
        DELETE FROM app.analysis_quota_reservations
        WHERE expires_at < now()
      `);
    } catch {
      // A failed cleanup must never make an API request fail. It will retry hourly.
    }
  }
}
