import type { AnalysisInput, DataQualityResult } from './types';

export interface DataQualityThresholds {
  weightLogsMin: number;
  activityDaysMin: number;
  nutritionDaysMin: number;
  sleepNightsMin: number;
  workoutCountMin: number;
}

export const DEFAULT_DATA_QUALITY_THRESHOLDS: DataQualityThresholds = {
  weightLogsMin: 2,
  activityDaysMin: 3,
  nutritionDaysMin: 3,
  sleepNightsMin: 3,
  workoutCountMin: 1,
};

export function evaluateDataQuality(
  input: AnalysisInput,
  thresholds: DataQualityThresholds = DEFAULT_DATA_QUALITY_THRESHOLDS,
): DataQualityResult {
  const trackedDays = new Set([
    ...input.weightLogs.map((w) => w.entryDate),
    ...input.activity.map((a) => a.date),
    ...input.nutrition.map((n) => n.date),
    ...input.sleep.map((s) => s.date),
    ...input.workouts.map((w) => w.date),
  ]).size;

  const weightLogsCount = input.weightLogs.length;
  const activityDays = input.activity.length;
  const nutritionDays = input.nutrition.length;
  const sleepNights = input.sleep.filter(
    (s) => s.asleepMinutes !== null,
  ).length;
  const workoutCount = input.workouts.length;

  const domainSufficient = {
    nutrition: weightLogsCount + nutritionDays >= 2,
    activity: activityDays >= thresholds.activityDaysMin,
    workout: workoutCount >= thresholds.workoutCountMin,
    sleep: sleepNights >= thresholds.sleepNightsMin,
  };

  const dimensions = 4;
  const score = Math.min(
    1,
    (weightLogsCount / thresholds.weightLogsMin +
      activityDays / thresholds.activityDaysMin +
      (nutritionDays / thresholds.nutritionDaysMin) * 0.5 +
      weightLogsCount / thresholds.weightLogsMin +
      sleepNights / thresholds.sleepNightsMin +
      workoutCount / thresholds.workoutCountMin) /
      dimensions /
      1.5,
  );

  const isEnough = Object.values(domainSufficient).some(Boolean);

  return {
    isEnough,
    score,
    trackedDays,
    weightLogsCount,
    activityDays,
    nutritionDays,
    sleepNights,
    workoutCount,
    domainSufficient,
  };
}
