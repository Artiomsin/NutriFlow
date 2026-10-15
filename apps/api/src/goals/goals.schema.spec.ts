import { describe, expect, it } from 'bun:test';

import { updateGoalsSchema } from './goals.schema';

describe('updateGoalsSchema', () => {
  it('accepts an empty patch and explicit nulls', () => {
    expect(updateGoalsSchema.safeParse({}).success).toBe(true);
    expect(
      updateGoalsSchema.safeParse({ dailyCaloriesGoal: null }).success,
    ).toBe(true);
  });

  it('rejects non-positive and non-integer values', () => {
    expect(updateGoalsSchema.safeParse({ dailyCaloriesGoal: 0 }).success).toBe(
      false,
    );
    expect(
      updateGoalsSchema.safeParse({ dailyCaloriesGoal: 2200.5 }).success,
    ).toBe(false);
  });

  it('rejects a sleep min above max', () => {
    const result = updateGoalsSchema.safeParse({
      nightlySleepMinMinutes: 600,
      nightlySleepMaxMinutes: 480,
    });
    expect(result.success).toBe(false);
  });

  it('accepts a valid partial update', () => {
    const result = updateGoalsSchema.safeParse({
      dailyCaloriesGoal: 2200,
      nightlySleepMinMinutes: 420,
      nightlySleepMaxMinutes: 480,
    });
    expect(result.success).toBe(true);
  });
});
