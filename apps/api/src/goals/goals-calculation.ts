import { roundNutrition } from '../common/nutrition/precision';
import type { GoalMetrics, SuggestedGoalPlan } from './personalization/types';
import type { GoalMode, ManualGoalOverrides } from '../db/schema/userGoals';

function addDays(dateStr: string, days: number): string {
  const d = new Date(`${dateStr}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

export type PrimaryGoal = 'lose' | 'gain' | 'maintain';
export type ActivityLevel = 'low' | 'medium' | 'high';
export type Gender = 'male' | 'female';

export interface GoalProfileInput {
  weightKg: number;
  heightCm: number;
  age: number;
  gender: Gender;
  goal: PrimaryGoal;
  activityLevel: ActivityLevel;
  targetWeightKg?: number | null;
  weeklyRateKg?: number | null;
  targetDate?: string | null; // YYYY-MM-DD
  goalStartedAt?: string | Date | null;
}

export interface CalorieCalculation {
  bmr: number;
  tdee: number;
  dailyCalories: number;
  rawDailyCalories: number;
  dailyDeltaKcal: number;
  targetRateKgPerWeek: number | null;
  paceSource:
    | 'explicit_rate'
    | 'target_date'
    | 'default_goal'
    | 'recommended_default'
    | 'maintain';
  minSafeCalories: number;
  maxSafeCalories: number;
  warnings: string[];
  limitedBySafety: boolean;
}

export interface GoalCalculationResult {
  metrics: GoalMetrics;
  calories: CalorieCalculation;
  basis: {
    currentWeightKg: number;
    targetWeightKg: number | null;
    weeklyRateKg: number | null;
    targetDate: string | null;
    goal: PrimaryGoal;
    activityLevel: ActivityLevel;
  };
}

const ACTIVITY_MULTIPLIERS: Record<ActivityLevel, number> = {
  low: 1.2,
  medium: 1.55,
  high: 1.9,
};

const WATER_PER_KG: Record<ActivityLevel, number> = {
  low: 30,
  medium: 35,
  high: 40,
};

const ACTIVITY_GOALS: Record<
  ActivityLevel,
  { steps: number; activeCalories: number }
> = {
  low: { steps: 5000, activeCalories: 200 },
  medium: { steps: 8000, activeCalories: 400 },
  high: { steps: 10000, activeCalories: 600 },
};

const WORKOUT_GOALS: Record<
  ActivityLevel,
  { workouts: number; minutes: number }
> = {
  low: { workouts: 2, minutes: 90 },
  medium: { workouts: 3, minutes: 150 },
  high: { workouts: 4, minutes: 180 },
};

const DEFAULT_GOAL_FACTORS: Record<PrimaryGoal, number> = {
  lose: 0.8,
  gain: 1.15,
  maintain: 1.0,
};

const SAFE_RATE_BOUNDS: Record<PrimaryGoal, { min: number; max: number }> = {
  lose: { min: 0.1, max: 1.0 },
  gain: { min: 0.05, max: 0.5 },
  maintain: { min: 0, max: 0 },
};

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

function daysBetween(start: string, end: string): number {
  const a = Date.parse(`${start}T00:00:00Z`);
  const b = Date.parse(`${end}T00:00:00Z`);
  if (!Number.isFinite(a) || !Number.isFinite(b)) return 0;
  return (b - a) / (24 * 60 * 60 * 1000);
}

export function calculateBmr(
  weightKg: number,
  heightCm: number,
  age: number,
  gender: Gender,
): number {
  const base = 10 * weightKg + 6.25 * heightCm - 5 * age;
  return gender === 'female' ? base - 161 : base + 5;
}

export function calculateTdee(
  bmr: number,
  activityLevel: ActivityLevel,
): number {
  return bmr * (ACTIVITY_MULTIPLIERS[activityLevel] ?? 1.2);
}

function resolveTargetRate(profile: GoalProfileInput): {
  targetRateKgPerWeek: number | null;
  paceSource: CalorieCalculation['paceSource'];
  warnings: string[];
} {
  const warnings: string[] = [];
  if (profile.goal === 'maintain') {
    return { targetRateKgPerWeek: 0, paceSource: 'maintain', warnings };
  }

  // Explicit weekly rate takes precedence.
  if (profile.weeklyRateKg != null && profile.weeklyRateKg > 0) {
    let rate = Math.abs(profile.weeklyRateKg);
    const bounds = SAFE_RATE_BOUNDS[profile.goal];
    if (rate < bounds.min) {
      rate = bounds.min;
      warnings.push('target_rate_increased_to_safe_minimum');
    } else if (rate > bounds.max) {
      rate = bounds.max;
      warnings.push('target_rate_limited_to_safe_maximum');
    }
    const signed = profile.goal === 'lose' ? -rate : rate;
    return {
      targetRateKgPerWeek: signed,
      paceSource: 'explicit_rate',
      warnings,
    };
  }

  // Derive from target date and target weight if possible.
  if (profile.targetWeightKg != null && profile.targetDate) {
    const startDate =
      profile.goalStartedAt instanceof Date
        ? profile.goalStartedAt.toISOString().slice(0, 10)
        : typeof profile.goalStartedAt === 'string' &&
            /^\d{4}-\d{2}-\d{2}/.test(profile.goalStartedAt)
          ? profile.goalStartedAt.slice(0, 10)
          : new Date().toISOString().slice(0, 10);
    const days = daysBetween(startDate, profile.targetDate);
    if (days >= 7) {
      const deltaKg = profile.targetWeightKg - profile.weightKg; // negative for loss
      let rate = (deltaKg / days) * 7;
      // Align sign with goal intent.
      if (profile.goal === 'lose' && rate > 0) {
        warnings.push('target_inconsistent_with_goal_using_default');
      } else if (profile.goal === 'gain' && rate < 0) {
        warnings.push('target_inconsistent_with_goal_using_default');
      } else {
        const abs = Math.abs(rate);
        const bounds = SAFE_RATE_BOUNDS[profile.goal];
        let boundedAbs = abs;
        if (boundedAbs < bounds.min) {
          boundedAbs = bounds.min;
          warnings.push('derived_rate_increased_to_safe_minimum');
        } else if (boundedAbs > bounds.max) {
          boundedAbs = bounds.max;
          warnings.push('derived_rate_limited_to_safe_maximum');
        }
        const signed = profile.goal === 'lose' ? -boundedAbs : boundedAbs;
        // If derived direction mismatched after sign fix, fall through.
        if (
          (profile.goal === 'lose' && deltaKg < 0) ||
          (profile.goal === 'gain' && deltaKg > 0)
        ) {
          return {
            targetRateKgPerWeek: signed,
            paceSource: 'target_date',
            warnings,
          };
        }
      }
    } else {
      warnings.push('target_date_too_close_using_default');
    }
  }

  // Measurable goal without explicit pace/date: use recommended safe default pace
  // so we can compute calories consistently and show approximate ETA.
  if (profile.targetWeightKg != null) {
    const defaultRate = profile.goal === 'lose' ? 0.5 : 0.25;
    const bounds = SAFE_RATE_BOUNDS[profile.goal];
    const bounded = clamp(defaultRate, bounds.min, bounds.max);
    const signed = profile.goal === 'lose' ? -bounded : bounded;
    return {
      targetRateKgPerWeek: signed,
      paceSource: 'recommended_default',
      warnings,
    };
  }

  // Legacy fallback when no measurable target is set.
  return { targetRateKgPerWeek: null, paceSource: 'default_goal', warnings };
}

export function calculateCalories(
  profile: GoalProfileInput,
): CalorieCalculation {
  const bmr = calculateBmr(
    profile.weightKg,
    profile.heightCm,
    profile.age,
    profile.gender,
  );
  const tdee = calculateTdee(bmr, profile.activityLevel);
  const { targetRateKgPerWeek, paceSource, warnings } =
    resolveTargetRate(profile);

  let rawDailyCalories: number;
  let dailyDeltaKcal: number;

  if (paceSource === 'default_goal') {
    rawDailyCalories = tdee * (DEFAULT_GOAL_FACTORS[profile.goal] ?? 1.0);
    dailyDeltaKcal = rawDailyCalories - tdee;
  } else if (paceSource === 'maintain' || targetRateKgPerWeek == null) {
    rawDailyCalories = tdee;
    dailyDeltaKcal = 0;
  } else {
    dailyDeltaKcal = (targetRateKgPerWeek * 7700) / 7;
    rawDailyCalories = tdee + dailyDeltaKcal;
  }

  // Safety bounds: never below max(BMR, floor) and keep reasonable relative to TDEE.
  const floor = profile.gender === 'female' ? 1200 : 1500;
  const minSafeCalories = Math.max(Math.round(bmr), floor);
  // Upper bound: avoid excessive surplus; also cap deficit implicitly via min.
  const maxDeficit = Math.round(tdee * 0.35);
  const maxSurplus = Math.round(tdee * 0.25);
  let maxSafeCalories = Math.round(tdee + maxSurplus);
  let minByTdee = Math.round(tdee - maxDeficit);
  if (profile.goal === 'gain') {
    minByTdee = Math.round(tdee); // no deficit for gain
  } else if (profile.goal === 'maintain') {
    minByTdee = Math.round(tdee * 0.9);
    maxSafeCalories = Math.round(tdee * 1.1);
  }
  const effectiveMin = Math.max(minSafeCalories, minByTdee);

  let dailyCalories = rawDailyCalories;
  let limitedBySafety = false;
  if (dailyCalories < effectiveMin) {
    dailyCalories = effectiveMin;
    limitedBySafety = true;
    warnings.push('calories_limited_by_safe_minimum');
  } else if (dailyCalories > maxSafeCalories) {
    dailyCalories = maxSafeCalories;
    limitedBySafety = true;
    warnings.push('calories_limited_by_safe_maximum');
  }

  return {
    bmr: roundNutrition(bmr),
    tdee: roundNutrition(tdee),
    dailyCalories: roundNutrition(dailyCalories),
    rawDailyCalories: roundNutrition(rawDailyCalories),
    dailyDeltaKcal: roundNutrition(dailyDeltaKcal),
    targetRateKgPerWeek,
    paceSource,
    minSafeCalories: effectiveMin,
    maxSafeCalories,
    warnings,
    limitedBySafety,
  };
}

export function calculateMacros(
  dailyCalories: number,
  weightKg: number,
  goal: PrimaryGoal,
): Pick<GoalMetrics, 'dailyProteinGoal' | 'dailyFatGoal' | 'dailyCarbsGoal'> {
  const proteinPerKg = goal === 'maintain' ? 1.6 : 2.0;
  const protein = weightKg * proteinPerKg;
  const fatKcal = dailyCalories * 0.25;
  const fat = fatKcal / 9;
  const carbsKcal = dailyCalories - protein * 4 - fat * 9;
  const carbs = Math.max(0, carbsKcal / 4);
  return {
    dailyProteinGoal: roundNutrition(protein),
    dailyFatGoal: roundNutrition(fat),
    dailyCarbsGoal: roundNutrition(carbs),
  };
}

export function calculateRecommendedMetrics(
  profile: GoalProfileInput,
): GoalCalculationResult {
  const calories = calculateCalories(profile);
  const macros = calculateMacros(
    calories.dailyCalories,
    profile.weightKg,
    profile.goal,
  );
  const water = Math.round(
    profile.weightKg * (WATER_PER_KG[profile.activityLevel] ?? 35),
  );
  const activity =
    ACTIVITY_GOALS[profile.activityLevel] ?? ACTIVITY_GOALS.medium;
  const workout = WORKOUT_GOALS[profile.activityLevel] ?? WORKOUT_GOALS.medium;

  const metrics: GoalMetrics = {
    dailyCaloriesGoal: calories.dailyCalories,
    dailyProteinGoal: macros.dailyProteinGoal,
    dailyFatGoal: macros.dailyFatGoal,
    dailyCarbsGoal: macros.dailyCarbsGoal,
    dailyWaterGoal: water,
    dailyStepsGoal: activity.steps,
    dailyActiveCaloriesGoal: activity.activeCalories,
    weeklyWorkoutsGoal: workout.workouts,
    weeklyWorkoutMinutesGoal: workout.minutes,
    nightlySleepMinMinutes: 420,
    nightlySleepMaxMinutes: 540,
  };

  return {
    metrics,
    calories,
    basis: {
      currentWeightKg: profile.weightKg,
      targetWeightKg: profile.targetWeightKg ?? null,
      weeklyRateKg: profile.weeklyRateKg ?? null,
      targetDate: profile.targetDate ?? null,
      goal: profile.goal,
      activityLevel: profile.activityLevel,
    },
  };
}

export function hasCompleteCalculationProfile(
  profile: Partial<GoalProfileInput> | null | undefined,
): profile is GoalProfileInput {
  if (!profile) return false;
  return (
    profile.weightKg != null &&
    profile.heightCm != null &&
    profile.age != null &&
    (profile.gender === 'male' || profile.gender === 'female') &&
    (profile.goal === 'lose' ||
      profile.goal === 'gain' ||
      profile.goal === 'maintain') &&
    (profile.activityLevel === 'low' ||
      profile.activityLevel === 'medium' ||
      profile.activityLevel === 'high')
  );
}

export function mapProfileRowToInput(row: {
  weight: number | null;
  height: number | null;
  age: number | null;
  gender: string | null;
  goal: string | null;
  activityLevel: string | null;
  targetWeightKg?: number | null;
  weeklyRateKg?: number | null;
  targetDate?: string | null;
  goalStartedAt?: Date | string | null;
}): GoalProfileInput | null {
  if (
    row.weight == null ||
    row.height == null ||
    row.age == null ||
    (row.gender !== 'male' && row.gender !== 'female') ||
    (row.goal !== 'lose' && row.goal !== 'gain' && row.goal !== 'maintain') ||
    (row.activityLevel !== 'low' &&
      row.activityLevel !== 'medium' &&
      row.activityLevel !== 'high')
  ) {
    return null;
  }
  return {
    weightKg: Number(row.weight),
    heightCm: Number(row.height),
    age: Number(row.age),
    gender: row.gender,
    goal: row.goal,
    activityLevel: row.activityLevel,
    targetWeightKg:
      row.targetWeightKg == null ? null : Number(row.targetWeightKg),
    weeklyRateKg: row.weeklyRateKg == null ? null : Number(row.weeklyRateKg),
    targetDate: row.targetDate ?? null,
    goalStartedAt: row.goalStartedAt ?? null,
  };
}

/**
 * Plan-level counterpart of a personalization adjustment: the new weekly rate
 * and a target date recalculated from the remaining distance at that rate.
 */
export function buildSuggestedGoalPlan(
  profile: GoalProfileInput,
  newRateKgPerWeek: number | null,
  today: string,
): SuggestedGoalPlan | null {
  if (
    newRateKgPerWeek == null ||
    newRateKgPerWeek <= 0 ||
    profile.goal === 'maintain' ||
    profile.targetWeightKg == null
  ) {
    return null;
  }
  const remaining = profile.targetWeightKg - profile.weightKg;
  if (
    (profile.goal === 'lose' && remaining >= 0) ||
    (profile.goal === 'gain' && remaining <= 0)
  ) {
    return null;
  }
  const weeks = Math.abs(remaining) / newRateKgPerWeek;
  if (!Number.isFinite(weeks) || weeks <= 0 || weeks > 520) return null;

  return {
    weeklyRateKg: Math.round(newRateKgPerWeek * 100) / 100,
    targetDate: addDays(today, Math.ceil(weeks * 7)),
    previousWeeklyRateKg: profile.weeklyRateKg ?? null,
    previousTargetDate: profile.targetDate ?? null,
  };
}

export function goalMetricsEqual(a: GoalMetrics, b: GoalMetrics): boolean {
  const keys = Object.keys(a) as (keyof GoalMetrics)[];
  return keys.every((k) => (a[k] ?? null) === (b[k] ?? null));
}

export function normalizeMetricsForComparison(m: GoalMetrics): GoalMetrics {
  return {
    dailyCaloriesGoal: m.dailyCaloriesGoal ?? null,
    dailyProteinGoal: m.dailyProteinGoal ?? null,
    dailyFatGoal: m.dailyFatGoal ?? null,
    dailyCarbsGoal: m.dailyCarbsGoal ?? null,
    dailyWaterGoal: m.dailyWaterGoal ?? null,
    dailyStepsGoal: m.dailyStepsGoal ?? null,
    dailyActiveCaloriesGoal: m.dailyActiveCaloriesGoal ?? null,
    weeklyWorkoutsGoal: m.weeklyWorkoutsGoal ?? null,
    weeklyWorkoutMinutesGoal: m.weeklyWorkoutMinutesGoal ?? null,
    nightlySleepMinMinutes: m.nightlySleepMinMinutes ?? null,
    nightlySleepMaxMinutes: m.nightlySleepMaxMinutes ?? null,
  };
}

export function modeFromSource(source: string | null | undefined): GoalMode {
  return source === 'user' ? 'manual' : 'auto';
}

export interface ManualSuggestionResult {
  suggested: GoalMetrics;
  preservedFixedFields: GoalMetricKey[];
  recalculatedFields: GoalMetricKey[];
  warnings: string[];
  conflicts: string[];
}

type GoalMetricKey = keyof GoalMetrics;
const NUTRITION_KEYS: GoalMetricKey[] = [
  'dailyCaloriesGoal',
  'dailyProteinGoal',
  'dailyFatGoal',
  'dailyCarbsGoal',
];

function isFixed(
  overrides: ManualGoalOverrides | null | undefined,
  key: GoalMetricKey,
): boolean {
  const v = overrides?.[key];
  return v != null && typeof v.value === 'number' && Number.isFinite(v.value);
}

export function getFixedMetricKeys(
  overrides: ManualGoalOverrides | null | undefined,
): GoalMetricKey[] {
  if (!overrides) return [];
  return (Object.keys(overrides) as GoalMetricKey[]).filter((k) =>
    isFixed(overrides, k),
  );
}

export function buildManualModeSuggestion(args: {
  applied: GoalMetrics;
  recommended: GoalMetrics;
  overrides: ManualGoalOverrides | null | undefined;
  profileInput: GoalProfileInput;
  recommendedCalories: { minSafeCalories: number; maxSafeCalories: number };
}): ManualSuggestionResult {
  const { applied, recommended, overrides, profileInput, recommendedCalories } =
    args;
  const fixed = new Set(getFixedMetricKeys(overrides));
  const preservedFixedFields: GoalMetricKey[] = [];
  const recalculatedFields: GoalMetricKey[] = [];
  const warnings: string[] = [];
  const conflicts: string[] = [];

  const suggested: GoalMetrics = { ...recommended };

  // Start by applying fixed values from applied (user intent).
  for (const key of fixed) {
    const value = applied[key];
    if (value != null) {
      suggested[key] = value;
      preservedFixedFields.push(key);
    }
  }

  // Nutrition consistency
  const caloriesFixed = fixed.has('dailyCaloriesGoal');
  const proteinFixed = fixed.has('dailyProteinGoal');
  const fatFixed = fixed.has('dailyFatGoal');
  const carbsFixed = fixed.has('dailyCarbsGoal');
  const anyNutritionFixed =
    caloriesFixed || proteinFixed || fatFixed || carbsFixed;

  if (anyNutritionFixed) {
    const weightKg = profileInput.weightKg;
    const goal = profileInput.goal;
    const proteinPerKg = goal === 'maintain' ? 1.6 : 2.0;
    const defaultProtein = roundNutrition(weightKg * proteinPerKg);

    let calories = caloriesFixed
      ? (applied.dailyCaloriesGoal ?? recommended.dailyCaloriesGoal ?? 0)
      : (recommended.dailyCaloriesGoal ?? applied.dailyCaloriesGoal ?? 0);

    let protein = proteinFixed
      ? (applied.dailyProteinGoal ?? defaultProtein)
      : defaultProtein;
    let fat = fatFixed
      ? (applied.dailyFatGoal ?? roundNutrition((calories * 0.25) / 9))
      : roundNutrition((calories * 0.25) / 9);
    let carbs = carbsFixed
      ? (applied.dailyCarbsGoal ?? 0)
      : roundNutrition(Math.max(0, (calories - protein * 4 - fat * 9) / 4));

    // If calories not fixed but all macros fixed, derive calories from macros.
    if (!caloriesFixed && proteinFixed && fatFixed && carbsFixed) {
      calories = roundNutrition(protein * 4 + fat * 9 + carbs * 4);
    } else if (!caloriesFixed && (proteinFixed || fatFixed || carbsFixed)) {
      // Keep fixed macros, fill unfixed macros from recommended split based on recommended calories.
      const baseCalories = recommended.dailyCaloriesGoal ?? calories;
      calories = baseCalories;
      if (!proteinFixed) protein = roundNutrition(weightKg * proteinPerKg);
      if (!fatFixed) fat = roundNutrition((calories * 0.25) / 9);
      if (!carbsFixed)
        carbs = roundNutrition(
          Math.max(0, (calories - protein * 4 - fat * 9) / 4),
        );
      // If resulting macro sum conflicts heavily, prefer macro sum and warn.
      const macroSum = roundNutrition(protein * 4 + fat * 9 + carbs * 4);
      if (Math.abs(macroSum - calories) > 1) {
        calories = macroSum;
        conflicts.push('calories_adjusted_to_match_fixed_macros');
      }
    } else if (caloriesFixed) {
      // Calories fixed: recalc unfixed macros from fixed calories.
      if (!proteinFixed) protein = roundNutrition(weightKg * proteinPerKg);
      if (!fatFixed) fat = roundNutrition((calories * 0.25) / 9);
      if (!carbsFixed)
        carbs = roundNutrition(
          Math.max(0, (calories - protein * 4 - fat * 9) / 4),
        );
      if (carbsFixed) {
        const macroSum = roundNutrition(protein * 4 + fat * 9 + carbs * 4);
        if (Math.abs(macroSum - calories) > 1) {
          conflicts.push('fixed_macros_do_not_match_fixed_calories');
        }
      }
    }

    // Safety warnings for fixed nutrition values (do not silently overwrite fixed).
    if (caloriesFixed) {
      if (calories < recommendedCalories.minSafeCalories)
        warnings.push('fixed_calories_below_safe_minimum');
      if (calories > recommendedCalories.maxSafeCalories)
        warnings.push('fixed_calories_above_safe_maximum');
    }

    suggested.dailyCaloriesGoal = calories;
    suggested.dailyProteinGoal = protein;
    suggested.dailyFatGoal = fat;
    suggested.dailyCarbsGoal = carbs;
  }

  // Non-nutrition fields: if not fixed, take recommended (already set). If fixed, preserved.
  const allKeys = Object.keys(recommended) as GoalMetricKey[];
  for (const key of allKeys) {
    if (fixed.has(key)) {
      if (!preservedFixedFields.includes(key)) preservedFixedFields.push(key);
      continue;
    }
    if ((suggested[key] ?? null) !== (applied[key] ?? null)) {
      recalculatedFields.push(key);
    }
  }

  // Mark nutrition recalculated fields accurately.
  for (const key of NUTRITION_KEYS) {
    if (fixed.has(key)) continue;
    const was = (applied[key] ?? null) !== (suggested[key] ?? null);
    if (was && !recalculatedFields.includes(key)) recalculatedFields.push(key);
    if (!was) {
      const idx = recalculatedFields.indexOf(key);
      if (idx >= 0) recalculatedFields.splice(idx, 1);
    }
  }

  return {
    suggested,
    preservedFixedFields,
    recalculatedFields,
    warnings,
    conflicts,
  };
}
