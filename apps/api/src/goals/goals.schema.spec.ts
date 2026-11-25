import { describe, expect, it } from 'bun:test';

import {
  applySuggestionSchema,
  clearManualOverrideSchema,
  goalsQuerySchema,
  newCycleSchema,
  previewDraftSchema,
  progressApplySchema,
  progressQuerySchema,
  updateGoalsSchema,
} from './goals.schema';
import {
  FieldErrorCode,
  fieldErrorsFromIssues,
} from '../common/validation/field-errors';

describe('goals.schema', () => {
  it('accepts an empty updateGoals patch and explicit nulls', () => {
    expect(updateGoalsSchema.safeParse({}).success).toBe(true);
    expect(
      updateGoalsSchema.safeParse({ dailyCaloriesGoal: null }).success,
    ).toBe(true);
  });

  it('rejects non-positive values and rounds nutrition goals to one decimal', () => {
    expect(updateGoalsSchema.safeParse({ dailyCaloriesGoal: 0 }).success).toBe(
      false,
    );
    expect(
      updateGoalsSchema.parse({ dailyCaloriesGoal: 2200.54 }).dailyCaloriesGoal,
    ).toBe(2200.5);
  });

  it('rejects a sleep min above max in updateGoals', () => {
    const result = updateGoalsSchema.safeParse({
      nightlySleepMinMinutes: 600,
      nightlySleepMaxMinutes: 480,
    });
    expect(result.success).toBe(false);
  });

  it('accepts valid partial updateGoals payload', () => {
    const result = updateGoalsSchema.safeParse({
      dailyCaloriesGoal: 2200,
      nightlySleepMinMinutes: 420,
      nightlySleepMaxMinutes: 480,
    });
    expect(result.success).toBe(true);
  });

  it('validates goalsQuery and progressQuery bounds', () => {
    expect(goalsQuerySchema.safeParse({ date: '2026-11-22' }).success).toBe(
      true,
    );
    expect(progressQuerySchema.parse({}).days).toBe(14);
    expect(progressQuerySchema.safeParse({ days: 6 }).success).toBe(false);
    expect(progressQuerySchema.safeParse({ days: 31 }).success).toBe(false);
  });

  it('validates progressApply optional metrics payload', () => {
    expect(progressApplySchema.safeParse(undefined).success).toBe(true);
    expect(progressApplySchema.safeParse({ days: 14 }).success).toBe(true);
    expect(
      progressApplySchema.safeParse({
        metrics: { dailyCaloriesGoal: 2100, dailyProteinGoal: 150 },
      }).success,
    ).toBe(true);
    expect(
      progressApplySchema.safeParse({
        metrics: { dailyCaloriesGoal: 0 },
      }).success,
    ).toBe(false);
  });

  it('validates clearManualOverride metric enum', () => {
    expect(
      clearManualOverrideSchema.safeParse({ metric: 'dailyCaloriesGoal' })
        .success,
    ).toBe(true);
    expect(
      clearManualOverrideSchema.safeParse({ metric: 'unknownMetric' }).success,
    ).toBe(false);
  });

  it('validates applySuggestionSchema metrics list', () => {
    expect(applySuggestionSchema.safeParse(undefined).success).toBe(true);
    expect(applySuggestionSchema.safeParse({}).success).toBe(true);
    expect(
      applySuggestionSchema.safeParse({ metrics: ['dailyCaloriesGoal'] })
        .success,
    ).toBe(true);
    expect(applySuggestionSchema.safeParse({ metrics: [] }).success).toBe(
      false,
    );
  });

  it('validates newCycleSchema set_new_goal requirements', () => {
    expect(
      newCycleSchema.safeParse({ action: 'maintain', goal: 'maintain' })
        .success,
    ).toBe(true);
    expect(
      newCycleSchema.safeParse({ action: 'set_new_goal', goal: 'lose' })
        .success,
    ).toBe(true);
    expect(newCycleSchema.safeParse({ action: 'set_new_goal' }).success).toBe(
      false,
    );
  });

  it('validates newCycleSchema adjust_tempo requires at least one field', () => {
    expect(newCycleSchema.safeParse({ action: 'adjust_tempo' }).success).toBe(
      false,
    );
    expect(
      newCycleSchema.safeParse({
        action: 'adjust_tempo',
        weeklyRateKg: 0.4,
      }).success,
    ).toBe(true);
  });

  it('rejects past targetDate in newCycleSchema', () => {
    const input = {
      action: 'set_new_goal',
      goal: 'lose',
      targetWeightKg: 70,
      targetDate: '2000-01-01',
    };
    const result = newCycleSchema.safeParse(input);
    expect(result.success).toBe(false);
    if (!result.success) {
      expect(fieldErrorsFromIssues(result.error.issues, input)).toContainEqual({
        field: 'targetDate',
        code: FieldErrorCode.targetDateInPast,
      });
    }
  });

  it('accepts maintain range fields in newCycleSchema', () => {
    const result = newCycleSchema.safeParse({
      action: 'maintain',
      goal: 'maintain',
      targetWeightMinKg: 69,
      targetWeightMaxKg: 71,
      targetWeightKg: 70,
    });
    expect(result.success).toBe(true);
  });

  it('validates previewDraft payload without a stored profile', () => {
    expect(
      previewDraftSchema.safeParse({
        weight: 80,
        height: 180,
        age: 30,
        gender: 'male',
        goal: 'lose',
        activityLevel: 'medium',
      }).success,
    ).toBe(true);
    expect(
      previewDraftSchema.safeParse({
        weight: 0,
        height: 180,
        age: 30,
        gender: 'male',
        goal: 'lose',
        activityLevel: 'medium',
      }).success,
    ).toBe(false);
  });
});
