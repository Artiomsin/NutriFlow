import { describe, expect, it } from 'bun:test';

import {
  buildManualModeSuggestion,
  buildSuggestedGoalPlan,
  calculateBmr,
  calculateCalories,
  calculateMacros,
  calculateRecommendedMetrics,
  calculateTdee,
  goalMetricsEqual,
  mapProfileRowToInput,
  modeFromSource,
  type GoalProfileInput,
} from './goals-calculation';
import type { GoalMetrics } from './personalization/types';
import type { PrimaryGoal } from './personalization/types';

const baseProfile: GoalProfileInput = {
  weightKg: 80,
  heightCm: 170,
  age: 30,
  gender: 'female',
  goal: 'lose',
  activityLevel: 'medium',
  targetWeightKg: 72,
  weeklyRateKg: null,
  targetDate: null,
  goalStartedAt: '2026-11-01',
};

function makeMetrics(overrides: Partial<GoalMetrics> = {}): GoalMetrics {
  return {
    dailyCaloriesGoal: 2000,
    dailyProteinGoal: 160,
    dailyFatGoal: 56,
    dailyCarbsGoal: 200,
    dailyWaterGoal: 2800,
    dailyStepsGoal: 8000,
    dailyActiveCaloriesGoal: 400,
    weeklyWorkoutMinutesGoal: 150,
    weeklyWorkoutsGoal: 3,
    nightlySleepMinMinutes: 420,
    nightlySleepMaxMinutes: 540,
    ...overrides,
  };
}

describe('goals-calculation', () => {
  it('calculates BMR with Mifflin-St Jeor for male and female', () => {
    expect(calculateBmr(80, 170, 30, 'female')).toBe(1551.5);
    expect(calculateBmr(60, 180, 20, 'male')).toBe(1630);
  });

  it('calculates TDEE from activity multipliers', () => {
    expect(calculateTdee(1630, 'low')).toBe(1956);
    expect(calculateTdee(1630, 'medium')).toBe(2526.5);
    expect(calculateTdee(1630, 'high')).toBe(3097);
  });

  it('uses recommended_default pace when lose goal has target but no pace/date', () => {
    const calc = calculateCalories(baseProfile);
    expect(calc.paceSource).toBe('recommended_default');
    expect(calc.targetRateKgPerWeek).toBe(-0.5);
    expect(calc.dailyDeltaKcal).toBe(-550);
    expect(calc.limitedBySafety).toBe(false);
  });

  it('limits derived target-date pace to safe maximum for gain', () => {
    const calc = calculateCalories({
      ...baseProfile,
      weightKg: 60,
      heightCm: 180,
      age: 20,
      gender: 'male',
      goal: 'gain',
      targetWeightKg: 70,
      weeklyRateKg: null,
      targetDate: '2027-03-22',
      goalStartedAt: '2026-11-22',
    });

    expect(calc.paceSource).toBe('target_date');
    expect(calc.targetRateKgPerWeek).toBe(0.5);
    expect(calc.warnings).toContain('derived_rate_limited_to_safe_maximum');
    expect(calc.dailyCalories).toBeGreaterThan(calc.tdee);
    expect(calc.dailyCalories).toBeLessThanOrEqual(calc.maxSafeCalories);
  });

  it('uses explicit rate and clamps it to safe bounds', () => {
    const calc = calculateCalories({
      ...baseProfile,
      weeklyRateKg: 2,
      targetDate: null,
    });
    expect(calc.paceSource).toBe('explicit_rate');
    expect(calc.targetRateKgPerWeek).toBe(-1);
    expect(calc.warnings).toContain('target_rate_limited_to_safe_maximum');
  });

  it('returns maintain pace for maintain goal', () => {
    const calc = calculateCalories({
      ...baseProfile,
      goal: 'maintain',
      targetWeightKg: 80,
    });
    expect(calc.paceSource).toBe('maintain');
    expect(calc.targetRateKgPerWeek).toBe(0);
    expect(calc.dailyDeltaKcal).toBe(0);
  });

  it('calculates macros by goal (protein 2.0/2.0/1.6, fat 25%)', () => {
    const lose = calculateMacros(2000, 80, 'lose');
    const gain = calculateMacros(2800, 70, 'gain');
    const maintain = calculateMacros(2200, 75, 'maintain');

    expect(lose.dailyProteinGoal).toBe(160);
    expect(gain.dailyProteinGoal).toBe(140);
    expect(maintain.dailyProteinGoal).toBe(120);

    expect(lose.dailyFatGoal).toBeCloseTo(55.56, 1);
    expect(lose.dailyCarbsGoal).toBeGreaterThan(0);
  });

  it('builds recommended metrics with water/activity/sleep defaults', () => {
    const result = calculateRecommendedMetrics(baseProfile);
    expect(result.metrics.dailyWaterGoal).toBe(2800);
    expect(result.metrics.dailyStepsGoal).toBe(8000);
    expect(result.metrics.weeklyWorkoutsGoal).toBe(3);
    expect(result.metrics.nightlySleepMinMinutes).toBe(420);
    expect(result.metrics.nightlySleepMaxMinutes).toBe(540);
    expect(result.basis.goal).toBe('lose');
  });

  it('maps profile row and normalizes invalid/missing values safely', () => {
    const mapped = mapProfileRowToInput({
      weight: 60,
      height: 180,
      age: 20,
      gender: 'male',
      goal: 'gain',
      activityLevel: 'medium',
      targetWeightKg: 70,
      weeklyRateKg: 0.25,
      targetDate: '2027-03-22',
      goalStartedAt: new Date('2026-11-22T00:00:00Z'),
    });
    expect(mapped).not.toBeNull();
    expect(mapped?.weeklyRateKg).toBe(0.25);
    expect(mapped?.targetDate).toBe('2027-03-22');

    expect(
      mapProfileRowToInput({
        weight: null,
        height: 180,
        age: 20,
        gender: 'male',
        goal: 'gain',
        activityLevel: 'medium',
      }),
    ).toBeNull();
  });

  it('compares goal metrics and maps source to mode', () => {
    const a = makeMetrics();
    const b = makeMetrics({ dailyCaloriesGoal: 2100 });
    expect(goalMetricsEqual(a, makeMetrics())).toBe(true);
    expect(goalMetricsEqual(a, b)).toBe(false);
    expect(modeFromSource('user')).toBe('manual');
    expect(modeFromSource('initial_calculation')).toBe('auto');
  });

  it('builds manual suggestion preserving fixed overrides and recalculating dependents', () => {
    const recommendedResult = calculateRecommendedMetrics(baseProfile);
    const applied = makeMetrics({
      dailyCaloriesGoal: 1700,
      dailyProteinGoal: 150,
    });
    const result = buildManualModeSuggestion({
      applied,
      recommended: recommendedResult.metrics,
      overrides: {
        dailyCaloriesGoal: { value: 1700, setAt: '2026-11-01T00:00:00Z' },
      },
      profileInput: baseProfile,
      recommendedCalories: {
        minSafeCalories: recommendedResult.calories.minSafeCalories,
        maxSafeCalories: recommendedResult.calories.maxSafeCalories,
      },
    });

    expect(result.preservedFixedFields).toContain('dailyCaloriesGoal');
    expect(result.suggested.dailyCaloriesGoal).toBe(1700);
    expect(result.recalculatedFields.length).toBeGreaterThan(0);
  });

  it('recalculates manual macros when only the target weight changes', () => {
    const applied = makeMetrics({ dailyCaloriesGoal: 1700 });
    const overrides = {
      dailyCaloriesGoal: { value: 1700, setAt: '2026-11-01T00:00:00Z' },
    };
    const buildForTarget = (targetWeightKg: number) => {
      const profile = { ...baseProfile, targetWeightKg };
      const recommendedResult = calculateRecommendedMetrics(profile);
      return buildManualModeSuggestion({
        applied,
        recommended: recommendedResult.metrics,
        overrides,
        profileInput: profile,
        recommendedCalories: {
          minSafeCalories: recommendedResult.calories.minSafeCalories,
          maxSafeCalories: recommendedResult.calories.maxSafeCalories,
        },
      });
    };

    const closerTarget = buildForTarget(76);
    const fartherTarget = buildForTarget(66);

    expect(closerTarget.suggested.dailyCaloriesGoal).toBe(1700);
    expect(fartherTarget.suggested.dailyCaloriesGoal).toBe(1700);
    expect(fartherTarget.suggested.dailyProteinGoal).not.toBe(
      closerTarget.suggested.dailyProteinGoal,
    );
    expect(fartherTarget.suggested.dailyCarbsGoal).not.toBe(
      closerTarget.suggested.dailyCarbsGoal,
    );
    expect(fartherTarget.recalculatedFields).toContain('dailyProteinGoal');
  });

  it('adds warning when fixed calories are below safe minimum', () => {
    const recommendedResult = calculateRecommendedMetrics(baseProfile);
    const applied = makeMetrics({ dailyCaloriesGoal: 900 });
    const result = buildManualModeSuggestion({
      applied,
      recommended: recommendedResult.metrics,
      overrides: {
        dailyCaloriesGoal: { value: 900, setAt: '2026-11-01T00:00:00Z' },
      },
      profileInput: baseProfile,
      recommendedCalories: {
        minSafeCalories: recommendedResult.calories.minSafeCalories,
        maxSafeCalories: recommendedResult.calories.maxSafeCalories,
      },
    });

    expect(result.warnings).toContain('fixed_calories_below_safe_minimum');
  });

  describe('buildSuggestedGoalPlan', () => {
    const today = '2026-11-26';

    it('returns plan for lose goal with remaining weight and valid rate', () => {
      const profile = {
        ...baseProfile,
        goal: 'lose' as PrimaryGoal,
        weightKg: 80,
        targetWeightKg: 72,
      } as GoalProfileInput;
      const plan = buildSuggestedGoalPlan(profile, 0.4, today);
      expect(plan).not.toBeNull();
      expect(plan!.weeklyRateKg).toBe(0.4);
      expect(plan!.previousWeeklyRateKg).toBeNull();
      // 8 kg / 0.4 kg/week = 20 weeks = 140 days → 2027-04-15
      expect(plan!.targetDate).toBe('2027-04-15');
    });

    it('returns plan for gain goal with remaining weight and valid rate', () => {
      const profile = {
        ...baseProfile,
        goal: 'gain' as PrimaryGoal,
        weightKg: 80,
        targetWeightKg: 88,
      } as GoalProfileInput;
      const plan = buildSuggestedGoalPlan(profile, 0.3, today);
      expect(plan).not.toBeNull();
      expect(plan!.weeklyRateKg).toBe(0.3);
      // 8 kg / 0.3 kg/week = 26.67 → 27 weeks = 189 days → 2027-06-01
      expect(plan!.targetDate).toBe('2027-06-01');
    });

    it('returns null for maintain goal', () => {
      const profile = {
        ...baseProfile,
        goal: 'maintain' as PrimaryGoal,
        weightKg: 80,
        targetWeightKg: 80,
      } as GoalProfileInput;
      const plan = buildSuggestedGoalPlan(profile, 0.5, today);
      expect(plan).toBeNull();
    });

    it('returns null when rate is zero or negative', () => {
      const profile = {
        ...baseProfile,
        weightKg: 80,
        targetWeightKg: 72,
      } as GoalProfileInput;
      expect(buildSuggestedGoalPlan(profile, 0, today)).toBeNull();
      expect(buildSuggestedGoalPlan(profile, -0.5, today)).toBeNull();
    });

    it('returns null when target weight already reached (lose)', () => {
      const profile = {
        ...baseProfile,
        goal: 'lose' as PrimaryGoal,
        weightKg: 70,
        targetWeightKg: 72,
      } as GoalProfileInput;
      expect(buildSuggestedGoalPlan(profile, 0.4, today)).toBeNull();
    });

    it('returns null when target weight already reached (gain)', () => {
      const profile = {
        ...baseProfile,
        goal: 'gain' as PrimaryGoal,
        weightKg: 90,
        targetWeightKg: 88,
      } as GoalProfileInput;
      expect(buildSuggestedGoalPlan(profile, 0.3, today)).toBeNull();
    });

    it('returns null when rate would take more than 520 weeks', () => {
      const profile = {
        ...baseProfile,
        weightKg: 80,
        targetWeightKg: 79.99,
      } as GoalProfileInput;
      const plan = buildSuggestedGoalPlan(profile, 0.00001, today);
      expect(plan).toBeNull();
    });

    it('rounds weeklyRateKg to 2 decimals', () => {
      const profile = {
        ...baseProfile,
        weightKg: 80,
        targetWeightKg: 72,
      } as GoalProfileInput;
      const plan = buildSuggestedGoalPlan(profile, 0.333, today);
      expect(plan!.weeklyRateKg).toBe(0.33);
    });
  });
});
