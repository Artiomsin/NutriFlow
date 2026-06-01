import { Injectable } from '@nestjs/common';
import { db } from '../db/db';
import { dailySummary } from '../db/schema/dailySummary';

import { eq, and, sql } from 'drizzle-orm';

@Injectable()
export class DailySummaryService {

  async findToday(userId: string) {
    const [summary] = await db
      .select()
      .from(dailySummary)
      .where(
        and(
          eq(dailySummary.userId, userId),
          sql`DATE(${dailySummary.date}) = CURRENT_DATE`,
        ),
      )
      .limit(1);

    return summary ?? this.empty();
  }

  async findByDate(userId: string, date?: string) {
    if (!date) return this.findToday(userId);

    const [summary] = await db
      .select()
      .from(dailySummary)
      .where(
        and(
          eq(dailySummary.userId, userId),
          sql`DATE(${dailySummary.date}) = ${date}::date`,
        ),
      )
      .limit(1);

    const target = new Date(date + 'T00:00:00');
    return summary ?? this.empty(target);
  }

  async findRange(userId: string, from: string, to: string) {
    const result = await db
      .select()
      .from(dailySummary)
      .where(
        and(
          eq(dailySummary.userId, userId),
          sql`DATE(${dailySummary.date}) >= ${from}::date`,
          sql`DATE(${dailySummary.date}) <= ${to}::date`,
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