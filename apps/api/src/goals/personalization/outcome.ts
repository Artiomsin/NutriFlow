import type { OutcomeResult, OutcomeVerdict, PrimaryGoal } from './types';

export const LOSING_HEALTHY_MIN = 0.2;
export const LOSING_HEALTHY_MAX = 0.8;
export const GAINING_HEALTHY_MAX = 0.6;
export const MAINTAIN_TOLERANCE = 0.3;

export function verdictForGoal(
  goal: PrimaryGoal,
  weeklyKg: number,
): OutcomeVerdict {
  switch (goal) {
    case 'lose':
      if (weeklyKg <= -LOSING_HEALTHY_MAX) return 'too_fast';
      if (weeklyKg >= -LOSING_HEALTHY_MIN) return 'plateau';
      return 'good';

    case 'gain':
      if (weeklyKg >= GAINING_HEALTHY_MAX) return 'too_fast';
      if (weeklyKg <= MAINTAIN_TOLERANCE * 0.66) return 'plateau';
      return 'good';

    case 'maintain':
      if (weeklyKg > MAINTAIN_TOLERANCE) return 'wrong_direction';
      if (weeklyKg < -MAINTAIN_TOLERANCE) return 'wrong_direction';
      return 'good';
  }
}

export function analyzeOutcome(
  goal: PrimaryGoal | null,
  baselineWeightTrendKgPerWeek: number | null,
): OutcomeResult {
  if (!goal || baselineWeightTrendKgPerWeek === null) {
    return {
      weightTrendKgPerWeek: baselineWeightTrendKgPerWeek,
      verdict: 'no_data',
    };
  }

  return {
    weightTrendKgPerWeek: baselineWeightTrendKgPerWeek,
    verdict: verdictForGoal(goal, baselineWeightTrendKgPerWeek),
  };
}
