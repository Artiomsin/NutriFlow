import { describe, expect, it } from 'bun:test';
import { createFoodEntrySchema } from './food.schema';
import { roundNutrition } from '../common/nutrition/precision';

describe('nutrition precision', () => {
  it('normalizes values to one decimal without discarding small macros', () => {
    expect(roundNutrition(0.30000000000000004)).toBe(0.3);
    expect(roundNutrition(130.64)).toBe(130.6);
    expect(roundNutrition(130.65)).toBe(130.7);
  });

  it('accepts decimal portions and macros in a food entry', () => {
    const result = createFoodEntrySchema.parse({
      name: 'Rice',
      grams: 100.44,
      calories: 130.64,
      protein: 2.44,
      fat: 0.34,
      carbs: 28.24,
    });

    expect(result).toMatchObject({
      grams: 100.4,
      calories: 130.6,
      protein: 2.4,
      fat: 0.3,
      carbs: 28.2,
    });
  });
});
