import { HttpException, HttpStatus, Inject, Injectable } from '@nestjs/common';
import { sql } from 'drizzle-orm';
import { env } from '../config/env';
import { DB } from '../db/db.module';
import type { Db } from '../db/db';

const QUOTA_WINDOW_MS = 24 * 60 * 60 * 1_000;
const PENDING_RESERVATION_MS = 2 * 60 * 1_000;

export interface AnalysisQuotaReservation {
  id: string;
  reservedAt: Date;
}

/** Caps paid analyses in a rolling 24-hour window, independent of time zone. */
@Injectable()
export class AnalysisQuotaService {
  private readonly limit = env.ANALYSIS_DAILY_LIMIT;

  constructor(@Inject(DB) private readonly db: Db) {}

  async remaining(userId: string): Promise<number> {
    const result = await this.db.execute<{ count: number | string }>(sql`
      SELECT COUNT(*) AS count
      FROM app.analysis_quota_reservations
      WHERE user_id = ${userId}::uuid AND expires_at > now()
    `);
    const count = Number(result.rows[0]?.count ?? 0);
    return Math.max(this.limit - count, 0);
  }

  /**
   * Serializes reservations per user, so requests from multiple devices or
   * application instances cannot jointly exceed the rolling 24-hour limit.
   */
  async tryReserve(userId: string): Promise<AnalysisQuotaReservation> {
    return this.db.transaction(async (tx) => {
      await tx.execute(sql`SELECT pg_advisory_xact_lock(hashtext(${userId}))`);

      const active = await tx.execute<{ count: number | string }>(sql`
        SELECT COUNT(*) AS count
        FROM app.analysis_quota_reservations
        WHERE user_id = ${userId}::uuid AND expires_at > now()
      `);
      if (Number(active.rows[0]?.count ?? 0) >= this.limit) {
        throw new HttpException(
          'Food analysis limit reached. Try again when a slot becomes available.',
          HttpStatus.TOO_MANY_REQUESTS,
        );
      }

      const result = await tx.execute<
        AnalysisQuotaReservation & Record<string, unknown>
      >(sql`
        INSERT INTO app.analysis_quota_reservations (
          user_id, status, reserved_at, expires_at
        )
        VALUES (
          ${userId}::uuid,
          'pending',
          now(),
          now() + ${PENDING_RESERVATION_MS} * interval '1 millisecond'
        )
        RETURNING id, reserved_at AS "reservedAt"
      `);
      return result.rows[0]!;
    });
  }

  /**
   * Turns a short-lived reservation into a consumed 24-hour quota slot after
   * the provider returns a successful analysis.
   */
  async consume(
    userId: string,
    reservation: AnalysisQuotaReservation,
  ): Promise<void> {
    await this.db.execute(sql`
      UPDATE app.analysis_quota_reservations
      SET status = 'consumed', expires_at = ${reservation.reservedAt} + ${QUOTA_WINDOW_MS} * interval '1 millisecond'
      WHERE id = ${reservation.id}::uuid
        AND user_id = ${userId}::uuid
        AND status = 'pending'
    `);
  }

  /** Returns exactly this pending slot after a failed analysis. */
  async release(
    userId: string,
    reservation: AnalysisQuotaReservation,
  ): Promise<void> {
    await this.db.execute(sql`
      DELETE FROM app.analysis_quota_reservations
      WHERE id = ${reservation.id}::uuid
        AND user_id = ${userId}::uuid
        AND status = 'pending'
    `);
  }
}
