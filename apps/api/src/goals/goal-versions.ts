import type { GoalMetrics } from './personalization/types';
import type { GoalSource } from '../db/schema/userGoals';

/** One goal field that differs between two consecutive versions. */
export interface GoalMetricChange {
  metric: keyof GoalMetrics;
  from: number | null;
  to: number | null;
}

/** Plan fields captured with a goal version. */
export interface GoalPlanSnapshot {
  targetWeightKg: number | null;
  targetWeightMinKg: number | null;
  targetWeightMaxKg: number | null;
  weeklyRateKg: number | null;
  targetDate: string | null;
}

export type GoalPlanValue = number | string | null;

export interface GoalPlanChange {
  metric: keyof GoalPlanSnapshot;
  from: GoalPlanValue;
  to: GoalPlanValue;
}

export const EMPTY_GOAL_PLAN: GoalPlanSnapshot = {
  targetWeightKg: null,
  targetWeightMinKg: null,
  targetWeightMaxKg: null,
  weeklyRateKg: null,
  targetDate: null,
};

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
  /** Plan changes captured when this version replaced the previous one. */
  planChanges: GoalPlanChange[];
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

/** Plan fields exposed as history rows, in display order. */
export const GOAL_PLAN_KEYS: (keyof GoalPlanSnapshot)[] = [
  'targetWeightKg',
  'targetWeightMinKg',
  'targetWeightMaxKg',
  'weeklyRateKg',
  'targetDate',
];

export function diffGoalPlan(
  previous: GoalPlanSnapshot,
  next: GoalPlanSnapshot,
): GoalPlanChange[] {
  return GOAL_PLAN_KEYS.flatMap((metric) => {
    const from = previous[metric];
    const to = next[metric];
    return from === to ? [] : [{ metric, from, to }];
  });
}

/** Reads a plan snapshot from version metadata written before this field existed. */
export function planFromBasis(basis: unknown): GoalPlanSnapshot | null {
  if (!basis || typeof basis !== 'object') return null;

  const value = basis as Record<string, unknown>;
  const hasPlan =
    'targetWeightKg' in value ||
    'weeklyRateKg' in value ||
    'targetDate' in value;
  if (!hasPlan) return null;

  return {
    targetWeightKg: numberOrNull(value.targetWeightKg),
    targetWeightMinKg: numberOrNull(value.targetWeightMinKg),
    targetWeightMaxKg: numberOrNull(value.targetWeightMaxKg),
    weeklyRateKg: numberOrNull(value.weeklyRateKg),
    targetDate: typeof value.targetDate === 'string' ? value.targetDate : null,
  };
}

function numberOrNull(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value === 'string' && value.trim() !== '') {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}
