import type { GoalMetrics } from './personalization/types';
import type { GoalSource } from '../db/schema/userGoals';

/** One goal field that differs between two consecutive versions. */
export interface GoalMetricChange {
  metric: keyof GoalMetrics;
  from: number | null;
  to: number | null;
}

/**
 * A single goal version as exposed by `GET /goals/history`.
 *
 * One entry is one change event, not one field. `changes` is the diff against
 * the version it replaced, so the list can be rendered without any client-side
 * coalescing.
 */
export interface GoalVersionEntry {
  id: string;
  startedAt: string;
  endedAt: string | null;
  source: GoalSource;
  reason: string | null;
  changes: GoalMetricChange[];
  /** Full snapshot of the version, used by the day detail timeline. */
  goal: GoalMetrics;
}

export interface GoalHistoryPage {
  items: GoalVersionEntry[];
  nextCursor: string | null;
}

/** Canonical metric order used for display and tests. */
export const GOAL_METRIC_KEYS: (keyof GoalMetrics)[] = [
  'dailyCaloriesGoal',
  'dailyProteinGoal',
  'dailyFatGoal',
  'dailyCarbsGoal',
  'dailyWaterGoal',
  'dailyStepsGoal',
  'dailyActiveCaloriesGoal',
  'weeklyWorkoutsGoal',
  'weeklyWorkoutMinutesGoal',
  'nightlySleepMinMinutes',
  'nightlySleepMaxMinutes',
];

/**
 * Fields that differ between the previous version and the current one.
 *
 * Passing `null` marks the very first version, so every non-null field is
 * reported as a change from an empty goal.
 */
export function diffGoalMetrics(
  previous: GoalMetrics | null,
  next: GoalMetrics,
): GoalMetricChange[] {
  return GOAL_METRIC_KEYS.flatMap((metric) => {
    const from = previous?.[metric] ?? null;
    const to = next[metric] ?? null;
    return from === to ? [] : [{ metric, from, to }];
  });
}
