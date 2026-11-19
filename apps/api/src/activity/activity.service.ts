import { Inject, Injectable } from '@nestjs/common';
import type { Db } from '../db/db';
import { DB } from '../db/db.module';
import { dailyActivity } from '../db/schema/dailyActivity';
import type { NewDailyActivity } from '../db/schema/dailyActivity';
import { dailySummary } from '../db/schema/dailySummary';
import { eq, and, sql } from 'drizzle-orm';
import type { SyncActivityDto } from './activity.schema';
import { currentUserDate } from '../common/time/user-date';
import { roundNutrition } from '../common/nutrition/precision';

@Injectable()
export class ActivityService {
  constructor(@Inject(DB) private readonly db: Db) {}

  async sync(userId: string, dto: SyncActivityDto) {
    const rows = await Promise.all(
      dto.entries.map(async (e) => {
        // A new day still gets the column defaults for metrics that were not
        // sent, so insert values keep the `?? 0` fallbacks.
        const insertValues: NewDailyActivity = {
          userId,
          date: e.date,
          steps: e.steps ?? 0,
          activeCalories: roundNutrition(e.activeCalories ?? 0),
          basalCalories: roundNutrition(e.basalCalories ?? 0),
          distanceMeters:
            e.distanceMeters != null ? String(e.distanceMeters) : '0',
        };

        // On conflict only overwrite metrics that actually arrived. A missing
        // key means the HealthKit read failed, not that the value became zero.
        const set: Partial<NewDailyActivity> = {};
        if (e.steps != null) set.steps = e.steps;
        if (e.activeCalories != null) {
          set.activeCalories = roundNutrition(e.activeCalories);
        }
        if (e.basalCalories != null) {
          set.basalCalories = roundNutrition(e.basalCalories);
        }
        if (e.distanceMeters != null) {
          set.distanceMeters = String(e.distanceMeters);
        }

        const insert = this.db.insert(dailyActivity).values(insertValues);
        // Drizzle cannot build an empty SET clause. If the entry carries only
        // a date, leave the existing row untouched.
        const query = Object.keys(set).length
          ? insert.onConflictDoUpdate({
              target: [dailyActivity.userId, dailyActivity.date],
              set,
            })
          : insert.onConflictDoNothing();

        const [row] = await query.returning();
        return row;
      }),
    );
    return rows.flat();
  }

  async getToday(userId: string, dateStr?: string) {
    const date = dateStr ?? (await currentUserDate(userId, this.db));
    const dateClause = sql`${date}::date`;
    const [row] = await this.db
      .select()
      .from(dailyActivity)
      .where(
        and(
          eq(dailyActivity.userId, userId),
          eq(dailyActivity.date, dateClause),
        ),
      )
      .limit(1);
    return (
      row ?? this.empty(dateStr ? new Date(dateStr + 'T00:00:00') : new Date())
    );
  }

  async getRange(userId: string, from: string, to: string) {
    const activity = await this.db
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

    const summaries = await this.db
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
