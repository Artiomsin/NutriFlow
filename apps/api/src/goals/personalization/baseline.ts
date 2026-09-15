import type { AnalysisInput, BaselineResult } from './types';

function mean(values: number[]): number | null {
  if (values.length === 0) return null;
  return values.reduce((s, v) => s + v, 0) / values.length;
}

export function weightTrendKgPerWeek(
  logs: AnalysisInput['weightLogs'],
): number | null {
  if (logs.length < 2) return null;

  const sorted = [...logs].sort((a, b) =>
    a.entryDate.localeCompare(b.entryDate),
  );

  const startMs = new Date(sorted[0]!.entryDate).getTime();
  const points = sorted.map((log) => ({
    x: (new Date(log.entryDate).getTime() - startMs) / (24 * 60 * 60 * 1000),
    y: log.weightKg,
  }));

  const n = points.length;
  const meanX = points.reduce((s, p) => s + p.x, 0) / n;
  const meanY = points.reduce((s, p) => s + p.y, 0) / n;

  let numerator = 0;
  let denominator = 0;
  for (const p of points) {
    numerator += (p.x - meanX) * (p.y - meanY);
    denominator += (p.x - meanX) ** 2;
  }

  if (denominator === 0) return null;

  const slopePerDay = numerator / denominator;
  return slopePerDay * 7;
}

export function calculateBaseline(input: AnalysisInput): BaselineResult {
  const sortedWeights = [...input.weightLogs].sort((a, b) =>
    a.entryDate.localeCompare(b.entryDate),
  );
  const latestWeightKg =
    sortedWeights.length > 0
      ? sortedWeights[sortedWeights.length - 1]!.weightKg
      : null;

  const stepsMean = mean(input.activity.map((a) => a.steps));
  const activeCaloriesMean = mean(input.activity.map((a) => a.activeCalories));
  const caloriesMean = mean(input.nutrition.map((n) => n.calories));
  const asleepMean = mean(
    input.sleep
      .map((s) => s.asleepMinutes)
      .filter((v): v is number => v !== null),
  );

  const periodStartMs = new Date(input.periodStart).getTime();
  const periodEndMs = new Date(input.periodEnd).getTime();
  const periodWeeks = Math.max(
    1,
    (periodEndMs - periodStartMs) / (7 * 24 * 60 * 60 * 1000),
  );

  const totalWorkoutMinutes = input.workouts.reduce(
    (s, w) => s + w.durationMinutes,
    0,
  );

  return {
    avgSteps: stepsMean,
    avgActiveCalories: activeCaloriesMean,
    avgCalories: caloriesMean,
    avgWorkoutsPerWeek:
      input.workouts.length > 0 ? input.workouts.length / periodWeeks : null,
    avgWorkoutMinutesPerWeek:
      totalWorkoutMinutes > 0 ? totalWorkoutMinutes / periodWeeks : null,
    avgAsleepMinutes: asleepMean,
    weightTrendKgPerWeek: weightTrendKgPerWeek(input.weightLogs),
    latestWeightKg,
  };
}
