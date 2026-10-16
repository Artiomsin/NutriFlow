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

  assertAllowed(userId: string): void {
    if (this.remaining(userId) <= 0) {
      throw new HttpException(
        'Daily food analysis limit reached. Please try again tomorrow.',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
  }

  consume(userId: string): void {
    const day = this.today();
    const entry = this.counters.get(userId);
    if (!entry || entry.day !== day) {
      this.counters.set(userId, { day, count: 1 });
      return;
    }
    entry.count += 1;
  }
}
