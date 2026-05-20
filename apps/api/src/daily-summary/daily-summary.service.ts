import { Injectable } from '@nestjs/common';
import { db } from '../db/db';
import { dailySummary } from '../db/schema/dailySummary';

import { eq, and, gte, lte, sql } from 'drizzle-orm';

@Injectable()
export class DailySummaryService {

  async findToday(userId: string) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const [summary] = await db
      .select()
      .from(dailySummary)
      .where(
        and(
          eq(dailySummary.userId, userId),
          eq(dailySummary.date, today),
        ),
      )
      .limit(1);

    return summary ?? this.empty();
  }

  async findByDate(userId: string, date?: string) {
    if (!date) return this.findToday(userId);

    const target = new Date(date);
    target.setHours(0, 0, 0, 0);

    const [summary] = await db
      .select()
      .from(dailySummary)
      .where(
        and(
          eq(dailySummary.userId, userId),
          eq(dailySummary.date, target),
        ),
      )
      .limit(1);

    return summary ?? this.empty(target);
  }

  async findRange(userId: string, from: string, to: string) {
    const fromDate = new Date(from);
    const toDate = new Date(to);

    fromDate.setHours(0, 0, 0, 0);
    toDate.setHours(23, 59, 59, 999);

    const result = await db
      .select()
      .from(dailySummary)
      .where(
        and(
          eq(dailySummary.userId, userId),
          gte(dailySummary.date, fromDate),
          lte(dailySummary.date, toDate),
        ),
      )
      .orderBy(dailySummary.date);

    return result;
  }

  private empty(date: Date = new Date()) {
    return {
      date,
      totalCalories: 0,
      totalProtein: 0,
      totalFat: 0,
      totalCarbs: 0,
      totalWaterMl: 0,
    };
  }
}