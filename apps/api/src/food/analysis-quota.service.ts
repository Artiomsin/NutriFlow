import { HttpException, HttpStatus, Inject, Injectable } from '@nestjs/common';
import { sql } from 'drizzle-orm';
import { env } from '../config/env';
import { DB } from '../db/db.module';
import type { Db } from '../db/db';

/**
 * Caps how many photo analyses a single user may run per day. The counter is
 * stored in PostgreSQL, so Render restarts and deploys cannot reset the quota.
 */
@Injectable()
export class AnalysisQuotaService {
  private readonly limit = env.ANALYSIS_DAILY_LIMIT;

  constructor(@Inject(DB) private readonly db: Db) {}

  private today(): string {
    return new Date().toISOString().slice(0, 10);
  }

  async remaining(userId: string): Promise<number> {
    const result = await this.db.execute<{ count: number | string }>(sql`
      SELECT count
      FROM app.analysis_quotas
      WHERE user_id = ${userId} AND date = ${this.today()}::date
    `);
    const count = Number(result.rows[0]?.count ?? 0);
    return Math.max(this.limit - count, 0);
  }

  /**
   * Atomically checks the daily limit and reserves a slot for the caller. The
   * check and the increment happen in one synchronous step, so a burst of
   * concurrent requests cannot slip past the limit while an earlier analysis
   * is still in flight (the previous assert-then-consume pair had that gap
   * across an `await`).
   */
  async tryReserve(userId: string): Promise<void> {
    const result = await this.db.execute(sql`
      INSERT INTO app.analysis_quotas AS quotas (user_id, date, count)
      VALUES (${userId}::uuid, ${this.today()}::date, 1)
      ON CONFLICT (user_id, date) DO UPDATE
      SET count = quotas.count + 1
      WHERE quotas.count < ${this.limit}
      RETURNING count
    `);
    if (!result.rows[0]) {
      throw new HttpException(
        'Daily food analysis limit reached. Please try again tomorrow.',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
  }

  /**
   * Returns a reserved slot after a failed analysis so the user can retry
   * without spending the day's quota on an error.
   */
  async release(userId: string): Promise<void> {
    await this.db.execute(sql`
      UPDATE app.analysis_quotas
      SET count = GREATEST(count - 1, 0)
      WHERE user_id = ${userId}::uuid AND date = ${this.today()}::date
    `);
  }
}
