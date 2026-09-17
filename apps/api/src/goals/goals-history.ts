import { db } from '../db/db';
import { goalHistory } from '../db/schema/goalHistory';
import type { GoalTypeValue } from '../db/schema/goalHistory';
import type { GoalSource } from '../db/schema/userGoals';
import type { GoalMetrics } from './personalization/types';

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
) {
  const rows = METRIC_KEYS.filter((key) => previous[key] !== next[key]).map(
    (key) => ({
      userId,
      goalType: GOAL_METRICS[key],
      metric: key,
      oldValue: previous[key],
      newValue: next[key],
      source,
      reason,
    }),
  );

  if (rows.length === 0) return;
  await db.insert(goalHistory).values(rows);
}
