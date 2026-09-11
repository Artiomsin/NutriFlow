import { Injectable } from '@nestjs/common';
import { db } from '../db/db';
import { dailyActivity } from '../db/schema/dailyActivity';
import { dailySummary } from '../db/schema/dailySummary';
import { eq, and, sql } from 'drizzle-orm';
import type { SyncActivityDto } from './activity.schema';

@Injectable()
export class ActivityService {

  async sync(userId: string, dto: SyncActivityDto) {
    const rows = await Promise.all(
      dto.entries.map((e) => {
        const values = {
          userId,
          date: e.date,
          steps: e.steps ?? 0,
          activeCalories: e.activeCalories ?? 0,
          basalCalories: e.basalCalories ?? 0,
          distanceMeters: e.distanceMeters != null ? String(e.distanceMeters) : '0',
        };
        return db
          .insert(dailyActivity)
          .values(values)
          .onConflictDoUpdate({
            target: [dailyActivity.userId, dailyActivity.date],
            set: {
              steps: sql`GREATEST(${dailyActivity.steps}, ${values.steps})`,
              activeCalories: sql`GREATEST(${dailyActivity.activeCalories}, ${values.activeCalories})`,
              basalCalories: sql`GREATEST(${dailyActivity.basalCalories}, ${values.basalCalories})`,
              distanceMeters: sql`GREATEST(${dailyActivity.distanceMeters}, ${values.distanceMeters})`,
            },
          })
          .returning();
      }),
    );
    return rows.flat();
  }

  async getToday(userId: string, dateStr?: string) {
    const dateClause = dateStr ? sql`${dateStr}::date` : sql`CURRENT_DATE`;
    const [row] = await db
      .select()
      .from(dailyActivity)
      .where(and(eq(dailyActivity.userId, userId), eq(dailyActivity.date, dateClause)))
      .limit(1);
    return row ?? this.empty(dateStr ? new Date(dateStr + 'T00:00:00') : new Date());
  }

  async getRange(userId: string, from: string, to: string) {
    const activity = await db
      .select()
      .from(dailyActivity)
      .where(
        and(
          eq(dailyActivity.userId, userId),
          sql`${dailyActivity.date} >= ${from}::date`,
          sql`${dailyActivity.date} <= ${to}::date`,
        ),
      )
      .orderBy(dailyActivity.date);

    const summaries = await db
      .select()
      .from(dailySummary)
      .where(
        and(
          eq(dailySummary.userId, userId),
          sql`${dailySummary.date} >= ${from}::date`,
          sql`${dailySummary.date} <= ${to}::date`,
        ),
      );

    const byDate = new Map(
      summaries.map((s) => [new Date(s.date).toISOString().split('T')[0], s]),
    );

    return activity.map((a) => {
      const key = new Date(a.date).toISOString().split('T')[0];
      const consumed = byDate.get(key)?.totalCalories ?? 0;
      return {
        date: key,
        steps: a.steps,
        activeCalories: a.activeCalories,
        basalCalories: a.basalCalories ?? 0,
        distanceMeters: Number(a.distanceMeters ?? 0),
        caloriesConsumed: consumed,
        netCalories: consumed - a.activeCalories,
      };
    });
  }

  private empty(date: Date = new Date()) {
    return {
      id: null,
      date,
      steps: 0,
      activeCalories: 0,
      basalCalories: 0,
      distanceMeters: '0',
    };
  }
}
  
