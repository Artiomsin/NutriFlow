import { describe, expect, it } from 'bun:test';

import {
  createFoodEntrySchema,
  createFoodSchema,
  searchFoodQuerySchema,
  updateFoodEntrySchema,
} from './food.schema';

describe('createFoodEntrySchema', () => {
  it('accepts a minimal valid entry', () => {
    const result = createFoodEntrySchema.safeParse({
      name: 'Banana',
      calories: 89,
    });
    expect(result.success).toBe(true);
  });

  it('rejects an empty name', () => {
    const result = createFoodEntrySchema.safeParse({ name: '', calories: 10 });
    expect(result.success).toBe(false);
  });

  it('rejects out-of-range calories', () => {
    expect(
      createFoodEntrySchema.safeParse({ name: 'X', calories: -1 }).success,
    ).toBe(false);
    expect(
      createFoodEntrySchema.safeParse({ name: 'X', calories: 5001 }).success,
    ).toBe(false);
  });

  it('rejects grams above 10000', () => {
    const result = createFoodEntrySchema.safeParse({
      name: 'X',
      calories: 10,
      grams: 10001,
    });
    expect(result.success).toBe(false);
  });

  it('accepts an explicit null category', () => {
    const result = createFoodEntrySchema.safeParse({
      name: 'X',
      calories: 10,
      categoryName: null,
    });
    expect(result.success).toBe(true);
  });

  it('rejects an impossible calendar date', () => {
    const result = createFoodEntrySchema.safeParse({
      name: 'X',
      calories: 10,
      date: '2026-02-30',
    });
    expect(result.success).toBe(false);
  });
});

describe('updateFoodEntrySchema', () => {
  it('accepts an empty patch', () => {
    expect(updateFoodEntrySchema.safeParse({}).success).toBe(true);
  });

  it('accepts detaching a category with null', () => {
    expect(
      updateFoodEntrySchema.safeParse({ categoryName: null }).success,
    ).toBe(true);
  });

  it('rejects a category name longer than 100 chars', () => {
    const result = updateFoodEntrySchema.safeParse({
      categoryName: 'x'.repeat(101),
    });
    expect(result.success).toBe(false);
  });
});

describe('createFoodSchema', () => {
  it('accepts a catalog food with servings', () => {
    const result = createFoodSchema.safeParse({
      name: 'Oats',
      caloriesPer100g: 389,
      servings: [{ name: 'bowl', grams: 40 }],
    });
    expect(result.success).toBe(true);
  });

  it('rejects caloriesPer100g above 1000', () => {
    const result = createFoodSchema.safeParse({
      name: 'Oats',
      caloriesPer100g: 1001,
    });
    expect(result.success).toBe(false);
  });

  it('rejects a serving with a blank name', () => {
    const result = createFoodSchema.safeParse({
      name: 'Oats',
      caloriesPer100g: 389,
      servings: [{ name: '', grams: 40 }],
    });
    expect(result.success).toBe(false);
  });
});

describe('searchFoodQuerySchema', () => {
  it('applies default limit and offset', () => {
    const result = searchFoodQuerySchema.safeParse({ q: 'apple' });
    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.limit).toBe(20);
      expect(result.data.offset).toBe(0);
    }
  });

  it('coerces numeric strings', () => {
    const result = searchFoodQuerySchema.safeParse({
      q: 'apple',
      limit: '5',
      offset: '10',
    });
    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.limit).toBe(5);
      expect(result.data.offset).toBe(10);
    }
  });

  it('trims the query and rejects blank input', () => {
    expect(searchFoodQuerySchema.safeParse({ q: '  ' }).success).toBe(false);
    const result = searchFoodQuerySchema.safeParse({ q: '  apple  ' });
    expect(result.success).toBe(true);
    if (result.success) expect(result.data.q).toBe('apple');
  });

  it('rejects limit above 50', () => {
    expect(
      searchFoodQuerySchema.safeParse({ q: 'apple', limit: '51' }).success,
    ).toBe(false);
  });
});
