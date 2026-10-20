import { Injectable, Inject } from '@nestjs/common';
import type { ThrottlerStorage } from '@nestjs/throttler';
import { sql } from 'drizzle-orm';
import { DB } from '../db/db.module';
import type { Db } from '../db/db';

type CounterRow = {
  totalHits: number | string;
  timeToExpire: number | string;
};

type ThrottlerStorageRecord = {
  totalHits: number;
  timeToExpire: number;
  isBlocked: boolean;
  timeToBlockExpire: number;
};

/**
 * Durable throttler storage. PostgreSQL's row lock on an upsert makes the
 * counter safe for concurrent requests and keeps it after a Render restart.
 */
@Injectable()
export class PostgresThrottlerStorage implements ThrottlerStorage {
  constructor(@Inject(DB) private readonly db: Db) {}

  async increment(
    key: string,
    ttl: number,
    limit: number,
  ): Promise<ThrottlerStorageRecord> {
    const ttlMs = Math.max(1, Math.floor(ttl));
    const result = await this.db.execute<CounterRow>(sql`
      INSERT INTO app.rate_limits AS counters (key, total_hits, expires_at)
      VALUES (${key}, 1, now() + (${ttlMs} * interval '1 millisecond'))
      ON CONFLICT (key) DO UPDATE
      SET
        total_hits = CASE
          WHEN counters.expires_at <= now() THEN 1
          ELSE counters.total_hits + 1
        END,
        expires_at = CASE
          WHEN counters.expires_at <= now()
            THEN now() + (${ttlMs} * interval '1 millisecond')
          ELSE counters.expires_at
        END
      RETURNING
        total_hits AS "totalHits",
        GREATEST(0, CEIL(EXTRACT(EPOCH FROM expires_at - now()))) AS "timeToExpire"
    `);
    const row = result.rows[0];
    if (!row) throw new Error('Rate limit counter did not return a row');

    const totalHits = Number(row.totalHits);
    const timeToExpire = Number(row.timeToExpire);
    const isBlocked = totalHits > limit;

    return {
      totalHits,
      timeToExpire,
      isBlocked,
      timeToBlockExpire: isBlocked ? timeToExpire : 0,
    };
  }
}
