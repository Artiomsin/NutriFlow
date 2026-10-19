import { HttpException, HttpStatus, Injectable } from '@nestjs/common';
import { env } from '../config/env';

type Counter = { day: string; count: number };

/**
 * Caps how many photo analyses a single user may run per day, so one account
 * cannot drain the shared provider quota. Counts live in memory, which is fine
 * for a single instance; move them to the database before scaling out.
 */
@Injectable()
export class AnalysisQuotaService {
  private readonly limit = env.ANALYSIS_DAILY_LIMIT;
  private readonly counters = new Map<string, Counter>();

  private today(): string {
    return new Date().toISOString().slice(0, 10);
  }

  remaining(userId: string): number {
    const entry = this.counters.get(userId);
    if (!entry || entry.day !== this.today()) {
      return this.limit;
    }
    return Math.max(this.limit - entry.count, 0);
  }

  /**
   * Atomically checks the daily limit and reserves a slot for the caller. The
   * check and the increment happen in one synchronous step, so a burst of
   * concurrent requests cannot slip past the limit while an earlier analysis
   * is still in flight (the previous assert-then-consume pair had that gap
   * across an `await`).
   */
  tryReserve(userId: string): void {
    if (this.remaining(userId) <= 0) {
      throw new HttpException(
        'Daily food analysis limit reached. Please try again tomorrow.',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
    this.increment(userId);
  }

  /**
   * Returns a reserved slot after a failed analysis so the user can retry
   * without spending the day's quota on an error.
   */
  release(userId: string): void {
    const entry = this.counters.get(userId);
    if (entry && entry.day === this.today() && entry.count > 0) {
      entry.count -= 1;
    }
  }

  private increment(userId: string): void {
    const day = this.today();
    const entry = this.counters.get(userId);
    if (!entry || entry.day !== day) {
      this.counters.set(userId, { day, count: 1 });
      return;
    }
    entry.count += 1;
  }
}
