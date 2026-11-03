import { describe, expect, it } from 'bun:test';
import { createFoodEntrySchema } from './food.schema';
import { roundGrams, roundNutrition } from '../common/nutrition/precision';

describe('nutrition precision', () => {
  it('normalizes values to one decimal without discarding small macros', () => {
    expect(roundNutrition(0.30000000000000004)).toBe(0.3);
    expect(roundNutrition(130.64)).toBe(130.6);
    expect(roundNutrition(130.65)).toBe(130.7);
  });

  it('rounds stored portions to three decimals independently of nutrition', () => {
    expect(roundGrams(1.55925)).toBe(1.559);
    expect(roundNutrition(3.118)).toBe(3.1);
  });

  it('accepts decimal portions and macros in a food entry', () => {
    const result = createFoodEntrySchema.parse({
      name: 'Rice',
      grams: 1.55925,
      calories: 130.64,
      protein: 2.44,
      fat: 0.34,
      carbs: 28.24,
    });

    expect(result).toMatchObject({
      grams: 1.559,
      calories: 130.6,
      protein: 2.4,
      fat: 0.3,
      carbs: 28.2,
    });
  });
});
