import type {
  AdherenceResult,
  AnalysisInput,
  CrossDomainResult,
} from './types';

export const SLEEP_RECOVERY_THRESHOLD = 85;
export const ENERGY_ADHERENCE_THRESHOLD = 80;

export function analyzeCrossDomain(
  input: AnalysisInput,
  adherence: AdherenceResult,
): CrossDomainResult {
  const warnings: string[] = [];
  let canIncreaseLoad = true;

  if (
    adherence.sleepPct !== null &&
    adherence.sleepPct < SLEEP_RECOVERY_THRESHOLD
  ) {
    warnings.push('sleep_below_current_goal');
    canIncreaseLoad = false;
  }

  if (
    adherence.caloriesPct !== null &&
    adherence.caloriesPct < ENERGY_ADHERENCE_THRESHOLD
  ) {
    warnings.push('calories_below_target');
  }

  const workoutsHigh =
    input.currentGoals.weeklyWorkoutsGoal !== null &&
    input.currentGoals.weeklyWorkoutsGoal >= 5;
  if (
    workoutsHigh &&
    adherence.workoutsPct !== null &&
    adherence.workoutsPct < 70
  ) {
    warnings.push('workout_volume_high_adherence_low');
  }

  return {
    canIncreaseLoad,
    warnings,
  };
}
