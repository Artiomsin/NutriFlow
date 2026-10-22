import type { Db } from '../db/db';
import { and, desc, eq, gte, inArray } from 'drizzle-orm';
import { goalHistory } from '../db/schema/goalHistory';
import type { GoalTypeValue } from '../db/schema/goalHistory';
import type { GoalSource } from '../db/schema/userGoals';
import type { GoalMetrics } from './personalization/types';

type DatabaseExecutor = Pick<Db, 'insert' | 'select' | 'update'>;

// Changes made during a single goal-adjustment session are represented by one
// history entry: `createdAt` remains the first edit and `updatedAt` tracks the
// latest adjustment in the session.
const GOAL_HISTORY_COALESCE_MS = 15 * 60 * 1000;

const GOAL_METRICS: Record<keyof GoalMetrics, GoalTypeValue> = {
  dailyCaloriesGoal: 'nutrition',
  dailyProteinGoal: 'nutrition',
  dailyFatGoal: 'nutrition',
  dailyCarbsGoal: 'nutrition',
  dailyWaterGoal: 'nutrition',
  dailyStepsGoal: 'activity',
  dailyActiveCaloriesGoal: 'activity',
  weeklyWorkoutsGoal: 'workout',
  weeklyWorkoutMinutesGoal: 'workout',
  nightlySleepMinMinutes: 'sleep',
  nightlySleepMaxMinutes: 'sleep',
};

const METRIC_KEYS = Object.keys(GOAL_METRICS) as (keyof GoalMetrics)[];

export const EMPTY_GOALS_METRICS: GoalMetrics = {
  dailyCaloriesGoal: null,
  dailyProteinGoal: null,
  dailyFatGoal: null,
  dailyCarbsGoal: null,
  dailyWaterGoal: null,
  dailyStepsGoal: null,
  dailyActiveCaloriesGoal: null,
  weeklyWorkoutsGoal: null,
  weeklyWorkoutMinutesGoal: null,
  nightlySleepMinMinutes: null,
  nightlySleepMaxMinutes: null,
};

export function rowToGoalMetrics(
  row: Record<string, unknown> | GoalMetrics | undefined,
): GoalMetrics {
  if (!row) return { ...EMPTY_GOALS_METRICS };
  return {
    dailyCaloriesGoal: (row.dailyCaloriesGoal as number | null) ?? null,
    dailyProteinGoal: (row.dailyProteinGoal as number | null) ?? null,
    dailyFatGoal: (row.dailyFatGoal as number | null) ?? null,
    dailyCarbsGoal: (row.dailyCarbsGoal as number | null) ?? null,
    dailyWaterGoal: (row.dailyWaterGoal as number | null) ?? null,
    dailyStepsGoal: (row.dailyStepsGoal as number | null) ?? null,
    dailyActiveCaloriesGoal:
      (row.dailyActiveCaloriesGoal as number | null) ?? null,
    weeklyWorkoutsGoal: (row.weeklyWorkoutsGoal as number | null) ?? null,
    weeklyWorkoutMinutesGoal:
      (row.weeklyWorkoutMinutesGoal as number | null) ?? null,
    nightlySleepMinMinutes:
      (row.nightlySleepMinMinutes as number | null) ?? null,
    nightlySleepMaxMinutes:
      (row.nightlySleepMaxMinutes as number | null) ?? null,
  };
}

export async function recordGoalHistory(
  userId: string,
  previous: GoalMetrics,
  next: GoalMetrics,
  source: GoalSource,
  reason: string,
  executor: DatabaseExecutor,
) {
  const changed = METRIC_KEYS.filter((key) => previous[key] !== next[key]);

  if (changed.length === 0) return;

  const recent = await executor
    .select()
    .from(goalHistory)
    .where(
      and(
        eq(goalHistory.userId, userId),
        inArray(goalHistory.metric, changed),
        eq(goalHistory.source, source),
        eq(goalHistory.reason, reason),
        gte(
          goalHistory.updatedAt,
          new Date(Date.now() - GOAL_HISTORY_COALESCE_MS),
        ),
      ),
    )
    .orderBy(desc(goalHistory.updatedAt));

  // `recent` is newest-first. Keep the newest row for each metric in case
  // legacy data already contains more than one entry in the time window.
  const recentByMetric = new Map<string, (typeof recent)[number]>();
  for (const row of recent) {
    if (!recentByMetric.has(row.metric)) {
      recentByMetric.set(row.metric, row);
    }
  }

  for (const key of changed) {
    const open = recentByMetric.get(key);

    if (open) {
      await executor
        .update(goalHistory)
        .set({ newValue: next[key], updatedAt: new Date() })
        .where(eq(goalHistory.id, open.id));
      continue;
    }

    await executor.insert(goalHistory).values({
      userId,
      goalType: GOAL_METRICS[key],
      metric: key,
      oldValue: previous[key],
      newValue: next[key],
      source,
      reason,
    });
  }
}
