import type { AdherenceResult, AnalysisInput, BaselineResult } from './types';

function pct(actual: number | null, goal: number | null): number | null {
  if (actual === null || goal === null || goal <= 0) return null;
  return Math.round((actual / goal) * 100);
}

export function calculateAdherence(
  input: AnalysisInput,
  baseline: BaselineResult,
): AdherenceResult {
  const goals = input.currentGoals;

  const sleepTarget =
    goals.nightlySleepMinMinutes !== null &&
    goals.nightlySleepMaxMinutes !== null
      ? (goals.nightlySleepMinMinutes + goals.nightlySleepMaxMinutes) / 2
      : null;

  return {
    caloriesPct: pct(baseline.avgCalories, goals.dailyCaloriesGoal),
    stepsPct: pct(baseline.avgSteps, goals.dailyStepsGoal),
    activeCaloriesPct: pct(
      baseline.avgActiveCalories,
      goals.dailyActiveCaloriesGoal,
    ),
    workoutsPct: pct(baseline.avgWorkoutsPerWeek, goals.weeklyWorkoutsGoal),
    workoutMinutesPct: pct(
      baseline.avgWorkoutMinutesPerWeek,
      goals.weeklyWorkoutMinutesGoal,
    ),
    sleepPct: pct(baseline.avgAsleepMinutes, sleepTarget),
  };
}
