/**
 * Nutrition values are persisted with one decimal place. Normalize at every
 * API boundary and after derived calculations so entries and daily totals use
 * the same values.
 */
export function roundNutrition(value: number): number {
  return Math.round((value + Number.EPSILON) * 10) / 10;
}

export function clampNutrition(value: number, max: number): number {
  return Math.min(max, Math.max(0, roundNutrition(value)));
}
