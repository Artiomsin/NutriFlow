import type {
  AdherenceResult,
  AnalysisInput,
  BaselineResult,
  ConfidenceLevel,
  CrossDomainResult,
  DataQualityResult,
  GoalMetrics,
  OutcomeResult,
  PrimaryGoal,
} from './types';

export interface RulesContext {
  input: AnalysisInput;
  baseline: BaselineResult;
  adherence: AdherenceResult;
  outcome: OutcomeResult;
  crossDomain: CrossDomainResult;
  dataQuality: DataQualityResult;
  confidence: ConfidenceLevel;
}

export interface RulesResult {
  recommendedGoals: GoalMetrics;
  reasons: string[];
  domainChanges: {
    nutrition: boolean;
    activity: boolean;
    workout: boolean;
    sleep: boolean;
  };
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

function roundStep(value: number, step: number): number {
  return Math.round(value / step) * step;
}

function strengthFactor(level: ConfidenceLevel): number {
  if (level === 'high') return 1;
  if (level === 'medium') return 0.5;
  return 0;
}

function bmr(
  weightKg: number,
  heightCm: number,
  age: number,
  gender: string | null,
): number {
  const base = 10 * weightKg + 6.25 * heightCm - 5 * age;
  return gender === 'female' ? base - 161 : base + 5;
}

function calorieFactor(
  primaryGoal: PrimaryGoal,
  outcome: OutcomeResult,
): number {
  const trend = outcome.weightTrendKgPerWeek;
  if (trend === null) return 1;

  switch (primaryGoal) {
    case 'lose':
      if (outcome.verdict === 'plateau') return 0.9;
      if (outcome.verdict === 'too_fast') return 1.05;
      return 1;
    case 'gain':
      if (outcome.verdict === 'plateau') return 1.1;
      if (outcome.verdict === 'too_fast') return 0.95;
      return 1;
    case 'maintain':
      if (trend > 0.3) return 0.95;
      if (trend < -0.3) return 1.05;
      return 1;
  }
}

export function applyAdjustmentRules(ctx: RulesContext): RulesResult {
  const current = ctx.input.currentGoals;
  const recommended: GoalMetrics = { ...current };
  const reasons: string[] = [];
  const domainChanges = {
    nutrition: false,
    activity: false,
    workout: false,
    sleep: false,
  };

  const s = strengthFactor(ctx.confidence);
  if (s === 0) {
    return { recommendedGoals: recommended, reasons, domainChanges };
  }

  // ---- Nutrition ----
  if (
    ctx.dataQuality.domainSufficient.nutrition &&
    current.dailyCaloriesGoal !== null &&
    ctx.input.profile.goal !== null
  ) {
    const factor = calorieFactor(ctx.input.profile.goal, ctx.outcome);
    const blended = 1 + (factor - 1) * s;

    const profile = ctx.input.profile;
    const floor =
      profile.weightKg && profile.heightCm && profile.age
        ? Math.max(
            1200,
            Math.round(
              bmr(
                profile.weightKg,
                profile.heightCm,
                profile.age,
                profile.gender,
              ),
            ),
          )
        : 1200;

    const newCalories = clamp(
      Math.round(current.dailyCaloriesGoal * blended),
      floor,
      Math.round(current.dailyCaloriesGoal * 1.15),
    );

    if (newCalories !== current.dailyCaloriesGoal) {
      recommended.dailyCaloriesGoal = newCalories;

      if (current.dailyProteinGoal !== null) {
        const protein = current.dailyProteinGoal;
        const newFat = Math.max(0, Math.round((newCalories * 0.25) / 9));
        recommended.dailyFatGoal = newFat;
        recommended.dailyCarbsGoal = Math.max(
          0,
          Math.round((newCalories - protein * 4 - newFat * 9) / 4),
        );
      }

      domainChanges.nutrition = true;
      reasons.push(`calories_${ctx.outcome.verdict}_adjusted`);
    }
  }

  // ---- Activity ----
  if (
    ctx.dataQuality.domainSufficient.activity &&
    ctx.baseline.avgSteps !== null &&
    ctx.baseline.avgSteps > 0
  ) {
    let target = roundStep(ctx.baseline.avgSteps * 1.1, 500);
    target = Math.round(target + (ctx.baseline.avgSteps - target) * (1 - s));
    if (ctx.input.currentGoals.dailyStepsGoal !== null) {
      const cur = ctx.input.currentGoals.dailyStepsGoal;
      target = clamp(target, Math.round(cur * 0.7), Math.round(cur * 1.3));
    }
    target = clamp(target, 3000, 15000);

    if (
      !ctx.crossDomain.canIncreaseLoad &&
      ctx.input.currentGoals.dailyStepsGoal !== null
    ) {
      target = Math.min(target, ctx.input.currentGoals.dailyStepsGoal);
    }

    if (
      ctx.input.currentGoals.dailyStepsGoal !== null &&
      target !== ctx.input.currentGoals.dailyStepsGoal
    ) {
      recommended.dailyStepsGoal = target;
      domainChanges.activity = true;
      reasons.push('steps_progressive_target');
    } else if (ctx.input.currentGoals.dailyStepsGoal === null) {
      recommended.dailyStepsGoal = target;
      domainChanges.activity = true;
      reasons.push('steps_initial_recommendation');
    }

    if (
      ctx.baseline.avgActiveCalories !== null &&
      ctx.baseline.avgActiveCalories > 0
    ) {
      let activeTarget = Math.round(ctx.baseline.avgActiveCalories * 1.1);
      activeTarget = Math.round(
        activeTarget +
          (ctx.baseline.avgActiveCalories - activeTarget) * (1 - s),
      );
      if (ctx.input.currentGoals.dailyActiveCaloriesGoal !== null) {
        const cur = ctx.input.currentGoals.dailyActiveCaloriesGoal;
        activeTarget = clamp(
          activeTarget,
          Math.round(cur * 0.7),
          Math.round(cur * 1.3),
        );
      }
      activeTarget = clamp(activeTarget, 100, 1200);

      if (
        !ctx.crossDomain.canIncreaseLoad &&
        ctx.input.currentGoals.dailyActiveCaloriesGoal !== null
      ) {
        activeTarget = Math.min(
          activeTarget,
          ctx.input.currentGoals.dailyActiveCaloriesGoal,
        );
      }

      if (
        ctx.input.currentGoals.dailyActiveCaloriesGoal !== null &&
        activeTarget !== ctx.input.currentGoals.dailyActiveCaloriesGoal
      ) {
        recommended.dailyActiveCaloriesGoal = activeTarget;
        domainChanges.activity = true;
        reasons.push('active_calories_progressive_target');
      } else if (ctx.input.currentGoals.dailyActiveCaloriesGoal === null) {
        recommended.dailyActiveCaloriesGoal = activeTarget;
        domainChanges.activity = true;
        reasons.push('active_calories_initial_recommendation');
      }
    }
  }

  // ---- Workout ----
  if (
    ctx.dataQuality.domainSufficient.workout &&
    ctx.baseline.avgWorkoutsPerWeek !== null &&
    ctx.baseline.avgWorkoutsPerWeek > 0
  ) {
    let workoutTarget = Math.round(ctx.baseline.avgWorkoutsPerWeek * 1.15);
    workoutTarget = Math.round(
      workoutTarget +
        (ctx.baseline.avgWorkoutsPerWeek - workoutTarget) * (1 - s),
    );
    workoutTarget = clamp(workoutTarget, 1, 7);
    if (ctx.input.currentGoals.weeklyWorkoutsGoal !== null) {
      workoutTarget = clamp(
        workoutTarget,
        Math.max(1, ctx.input.currentGoals.weeklyWorkoutsGoal - 1),
        ctx.input.currentGoals.weeklyWorkoutsGoal + 1,
      );
    }
    if (
      !ctx.crossDomain.canIncreaseLoad &&
      ctx.input.currentGoals.weeklyWorkoutsGoal !== null
    ) {
      workoutTarget = Math.min(
        workoutTarget,
        ctx.input.currentGoals.weeklyWorkoutsGoal,
      );
    }

    if (
      ctx.input.currentGoals.weeklyWorkoutsGoal !== null &&
      workoutTarget !== ctx.input.currentGoals.weeklyWorkoutsGoal
    ) {
      recommended.weeklyWorkoutsGoal = workoutTarget;
      domainChanges.workout = true;
      reasons.push('workouts_progressive_target');
    } else if (ctx.input.currentGoals.weeklyWorkoutsGoal === null) {
      recommended.weeklyWorkoutsGoal = workoutTarget;
      domainChanges.workout = true;
      reasons.push('workouts_initial_recommendation');
    }

    if (
      ctx.baseline.avgWorkoutMinutesPerWeek !== null &&
      ctx.baseline.avgWorkoutMinutesPerWeek > 0
    ) {
      let minuteTarget = Math.round(
        ctx.baseline.avgWorkoutMinutesPerWeek * 1.1,
      );
      minuteTarget = Math.round(
        minuteTarget +
          (ctx.baseline.avgWorkoutMinutesPerWeek - minuteTarget) * (1 - s),
      );
      minuteTarget = clamp(minuteTarget, 30, 600);
      if (ctx.input.currentGoals.weeklyWorkoutMinutesGoal !== null) {
        minuteTarget = clamp(
          minuteTarget,
          Math.round(ctx.input.currentGoals.weeklyWorkoutMinutesGoal * 0.7),
          Math.round(ctx.input.currentGoals.weeklyWorkoutMinutesGoal * 1.3),
        );
      }
      if (
        !ctx.crossDomain.canIncreaseLoad &&
        ctx.input.currentGoals.weeklyWorkoutMinutesGoal !== null
      ) {
        minuteTarget = Math.min(
          minuteTarget,
          ctx.input.currentGoals.weeklyWorkoutMinutesGoal,
        );
      }

      if (
        ctx.input.currentGoals.weeklyWorkoutMinutesGoal !== null &&
        minuteTarget !== ctx.input.currentGoals.weeklyWorkoutMinutesGoal
      ) {
        recommended.weeklyWorkoutMinutesGoal = minuteTarget;
        domainChanges.workout = true;
        reasons.push('workout_minutes_progressive_target');
      } else if (ctx.input.currentGoals.weeklyWorkoutMinutesGoal === null) {
        recommended.weeklyWorkoutMinutesGoal = minuteTarget;
        domainChanges.workout = true;
        reasons.push('workout_minutes_initial_recommendation');
      }
    }
  }

  // ---- Sleep ----
  if (
    ctx.dataQuality.domainSufficient.sleep &&
    ctx.baseline.avgAsleepMinutes !== null
  ) {
    const avg = ctx.baseline.avgAsleepMinutes;
    let newMin = clamp(Math.round(avg - 30), 330, 600);
    let newMax = clamp(Math.round(avg + 40), 390, 720);
    if (newMax <= newMin) newMax = newMin + 60;

    const currentMin = ctx.input.currentGoals.nightlySleepMinMinutes;
    const currentMax = ctx.input.currentGoals.nightlySleepMaxMinutes;
    if (currentMin !== null && currentMax !== null) {
      const midpoint = (currentMin + currentMax) / 2;
      const minTarget = Math.round(midpoint + (newMin - midpoint) * s);
      const maxTarget = Math.round(midpoint + (newMax - midpoint) * s);
      newMin = clamp(minTarget, 330, 600);
      newMax = clamp(maxTarget, 390, 720);
      if (newMax <= newMin) newMax = newMin + 60;
    }

    if (
      recommended.nightlySleepMinMinutes !== newMin ||
      recommended.nightlySleepMaxMinutes !== newMax
    ) {
      recommended.nightlySleepMinMinutes = newMin;
      recommended.nightlySleepMaxMinutes = newMax;
      domainChanges.sleep = true;
      reasons.push('sleep_aligned_to_reality');
    }
  }

  return { recommendedGoals: recommended, reasons, domainChanges };
}
