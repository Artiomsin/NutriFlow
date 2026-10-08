import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { db } from '../db/db';
import { userGoals } from '../db/schema/userGoals';
import { goalRecommendations } from '../db/schema/goalRecommendations';
import { userProfiles } from '../db/schema/userProfiles';
import { and, desc, eq } from 'drizzle-orm';
import type { UpdateGoalsDto } from './goals.schema';
import type { GoalMetrics } from './personalization/types';
import {
  recordGoalHistory,
  rowToGoalMetrics,
  EMPTY_GOALS_METRICS,
} from './goals-history';

type DatabaseExecutor = Pick<typeof db, 'select' | 'insert' | 'update'>;

@Injectable()
export class GoalsService {
  async findByUserId(userId: string) {
    const [goals] = await db
      .select()
      .from(userGoals)
      .where(eq(userGoals.userId, userId))
      .limit(1);

    if (!goals) {
      throw new NotFoundException('Goals not found');
    }

    return goals;
  }

  async update(userId: string, data: UpdateGoalsDto) {
    const existing = await this.findByUserIdSafe(userId);

    if (existing) {
      const [goals] = await db
        .update(userGoals)
        .set({
          ...data,
          source: 'user',
          updatedAt: new Date(),
        })
        .where(eq(userGoals.userId, userId))
        .returning();

      await recordGoalHistory(
        userId,
        rowToGoalMetrics(existing),
        rowToGoalMetrics(goals),
        'user',
        'user_edit',
      );
      return goals;
    }

    const [goals] = await db
      .insert(userGoals)
      .values({
        userId,
        ...data,
        source: 'user',
      })
      .returning();

    await recordGoalHistory(
      userId,
      EMPTY_GOALS_METRICS,
      rowToGoalMetrics(goals),
      'user',
      'user_edit',
    );
    return goals;
  }

  async calculate(
    userId: string,
    executor: DatabaseExecutor = db,
    forceAutomatic = false,
  ) {
    const [profile] = await executor
      .select()
      .from(userProfiles)
      .where(eq(userProfiles.userId, userId))
      .limit(1);

    if (!profile) {
      throw new NotFoundException('Profile not found');
    }

    const { weight, height, age, gender, goal, activityLevel } = profile;

    if (!weight || !height || !age || !gender || !goal || !activityLevel) {
      throw new BadRequestException(
        'Not enough profile data to calculate goals. Provide weight, height, age, gender, goal and activityLevel.',
      );
    }

    // Nutrition
    const bmr = this.calculateBMR(weight, height, age, gender);
    const tdee = this.calculateTDEE(bmr, activityLevel);
    const goalCalories = this.adjustForGoal(tdee, goal);

    const protein = this.calculateProtein(weight, goal);
    const fat = (goalCalories * 0.25) / 9;

    const proteinCals = protein * 4;
    const fatCals = fat * 9;

    const carbs = (goalCalories - proteinCals - fatCals) / 4;

    const waterMultipliers: Record<string, number> = {
      low: 30,
      medium: 35,
      high: 40,
    };

    const water = weight * (waterMultipliers[activityLevel] ?? 35);

    // Activity / workout / sleep
    const activityGoals = this.calculateActivityGoals(activityLevel);

    const workoutGoals = this.calculateWorkoutGoals(activityLevel);

    const sleepGoals = this.calculateSleepGoals();

    const calculated = {
      // Nutrition
      dailyCaloriesGoal: Math.round(goalCalories),
      dailyProteinGoal: Math.round(protein),
      dailyFatGoal: Math.round(fat),
      dailyCarbsGoal: Math.round(carbs),
      dailyWaterGoal: Math.round(water),

      // Activity
      dailyStepsGoal: activityGoals.steps,
      dailyActiveCaloriesGoal: activityGoals.activeCalories,

      // Workout
      weeklyWorkoutsGoal: workoutGoals.workouts,
      weeklyWorkoutMinutesGoal: workoutGoals.minutes,

      // Sleep
      nightlySleepMinMinutes: sleepGoals.minMinutes,
      nightlySleepMaxMinutes: sleepGoals.maxMinutes,
    };

    const existing = await this.findByUserIdSafe(userId, executor);

    if (existing) {
      if (existing.source === 'user' && !forceAutomatic) {
        const merged = {
          dailyCaloriesGoal:
            existing.dailyCaloriesGoal ?? calculated.dailyCaloriesGoal,

          dailyProteinGoal:
            existing.dailyProteinGoal ?? calculated.dailyProteinGoal,

          dailyFatGoal: existing.dailyFatGoal ?? calculated.dailyFatGoal,

          dailyCarbsGoal: existing.dailyCarbsGoal ?? calculated.dailyCarbsGoal,

          dailyWaterGoal: existing.dailyWaterGoal ?? calculated.dailyWaterGoal,

          dailyStepsGoal: existing.dailyStepsGoal ?? calculated.dailyStepsGoal,

          dailyActiveCaloriesGoal:
            existing.dailyActiveCaloriesGoal ??
            calculated.dailyActiveCaloriesGoal,

          weeklyWorkoutsGoal:
            existing.weeklyWorkoutsGoal ?? calculated.weeklyWorkoutsGoal,

          weeklyWorkoutMinutesGoal:
            existing.weeklyWorkoutMinutesGoal ??
            calculated.weeklyWorkoutMinutesGoal,

          nightlySleepMinMinutes:
            existing.nightlySleepMinMinutes ??
            calculated.nightlySleepMinMinutes,

          nightlySleepMaxMinutes:
            existing.nightlySleepMaxMinutes ??
            calculated.nightlySleepMaxMinutes,

          source: 'user' as const,
          updatedAt: new Date(),
        };

        const goalValuesChanged =
          existing.dailyCaloriesGoal !== merged.dailyCaloriesGoal ||
          existing.dailyProteinGoal !== merged.dailyProteinGoal ||
          existing.dailyFatGoal !== merged.dailyFatGoal ||
          existing.dailyCarbsGoal !== merged.dailyCarbsGoal ||
          existing.dailyWaterGoal !== merged.dailyWaterGoal ||
          existing.dailyStepsGoal !== merged.dailyStepsGoal ||
          existing.dailyActiveCaloriesGoal !== merged.dailyActiveCaloriesGoal ||
          existing.weeklyWorkoutsGoal !== merged.weeklyWorkoutsGoal ||
          existing.weeklyWorkoutMinutesGoal !== merged.weeklyWorkoutMinutesGoal ||
          existing.nightlySleepMinMinutes !== merged.nightlySleepMinMinutes ||
          existing.nightlySleepMaxMinutes !== merged.nightlySleepMaxMinutes;

        // Manual goals are an explicit user choice. Do not replace them from
        // a profile or weight update, and do not write no-op history rows.
        if (!goalValuesChanged) {
          return existing;
        }

        const [goals] = await executor
          .update(userGoals)
          .set(merged)
          .where(eq(userGoals.userId, userId))
          .returning();

        await recordGoalHistory(
          userId,
          rowToGoalMetrics(existing),
          rowToGoalMetrics(goals),
          goals?.source ?? 'user',
          'profile_recalculation',
          executor,
        );

        return goals;
      }

      if (existing.source === 'personalized' && !forceAutomatic) {
        const personalized = await this.applyLatestRecommendationAdjustment(
          userId,
          calculated,
          executor,
        );
        const merged = {
          ...personalized,
          source: 'personalized' as const,
          updatedAt: new Date(),
        };

        const goalValuesChanged =
          existing.dailyCaloriesGoal !== merged.dailyCaloriesGoal ||
          existing.dailyProteinGoal !== merged.dailyProteinGoal ||
          existing.dailyFatGoal !== merged.dailyFatGoal ||
          existing.dailyCarbsGoal !== merged.dailyCarbsGoal ||
          existing.dailyWaterGoal !== merged.dailyWaterGoal ||
          existing.dailyStepsGoal !== merged.dailyStepsGoal ||
          existing.dailyActiveCaloriesGoal !== merged.dailyActiveCaloriesGoal ||
          existing.weeklyWorkoutsGoal !== merged.weeklyWorkoutsGoal ||
          existing.weeklyWorkoutMinutesGoal !== merged.weeklyWorkoutMinutesGoal ||
          existing.nightlySleepMinMinutes !== merged.nightlySleepMinMinutes ||
          existing.nightlySleepMaxMinutes !== merged.nightlySleepMaxMinutes;

        if (!goalValuesChanged) {
          return existing;
        }

        const [goals] = await executor
          .update(userGoals)
          .set(merged)
          .where(eq(userGoals.userId, userId))
          .returning();

        await recordGoalHistory(
          userId,
          rowToGoalMetrics(existing),
          rowToGoalMetrics(goals),
          'personalized',
          'personalized_profile_recalculation',
          executor,
        );

        return goals;
      }

      const [goals] = await executor
        .update(userGoals)
        .set({
          ...calculated,
          source: 'initial',
          updatedAt: new Date(),
        })
        .where(eq(userGoals.userId, userId))
        .returning();

      await recordGoalHistory(
        userId,
        rowToGoalMetrics(existing),
        rowToGoalMetrics(goals),
        'initial',
        forceAutomatic
          ? 'manual_reset_to_automatic'
          : 'profile_recalculation',
        executor,
      );

      return goals;
    }

    const [goals] = await executor
      .insert(userGoals)
      .values({
        userId,
        ...calculated,
        source: 'initial',
      })
      .returning();

    await recordGoalHistory(
      userId,
      EMPTY_GOALS_METRICS,
      rowToGoalMetrics(goals),
      'initial',
      'initial_calculation',
      executor,
    );

    return goals;
  }

  async resetToAutomatic(userId: string) {
    return this.calculate(userId, db, true);
  }

  /**
   * A recommendation is a delta from the goals it evaluated. Keeping that
   * delta lets a personalized plan follow later profile/weight changes
   * without silently discarding the recommendation itself.
   */
  private async applyLatestRecommendationAdjustment(
    userId: string,
    calculated: GoalMetrics,
    executor: DatabaseExecutor,
  ): Promise<GoalMetrics> {
    const [recommendation] = await executor
      .select({
        previousGoals: goalRecommendations.previousGoals,
        recommendedGoals: goalRecommendations.recommendedGoals,
      })
      .from(goalRecommendations)
      .where(
        and(
          eq(goalRecommendations.userId, userId),
          eq(goalRecommendations.status, 'accepted'),
        ),
      )
      .orderBy(
        desc(goalRecommendations.acceptedAt),
        desc(goalRecommendations.createdAt),
      )
      .limit(1);

    if (!recommendation) return calculated;

    const adjusted = {} as GoalMetrics;
    for (const key of Object.keys(calculated) as (keyof GoalMetrics)[]) {
      const baseline = calculated[key];
      const previous = recommendation.previousGoals[key];
      const recommended = recommendation.recommendedGoals[key];

      adjusted[key] =
        baseline == null || previous == null || recommended == null
          ? baseline
          : Math.max(0, Math.round(baseline + (recommended - previous)));
    }

    return adjusted;
  }

  private calculateActivityGoals(activityLevel: string) {
    const goals = {
      low: {
        steps: 5000,
        activeCalories: 200,
      },
      medium: {
        steps: 8000,
        activeCalories: 400,
      },
      high: {
        steps: 10000,
        activeCalories: 600,
      },
    };

    return goals[activityLevel as keyof typeof goals] ?? goals.medium;
  }

  private calculateWorkoutGoals(activityLevel: string) {
    const goals = {
      low: {
        workouts: 2,
        minutes: 90,
      },
      medium: {
        workouts: 3,
        minutes: 150,
      },
      high: {
        workouts: 4,
        minutes: 180,
      },
    };

    return goals[activityLevel as keyof typeof goals] ?? goals.medium;
  }

  private calculateSleepGoals() {
    return {
      minMinutes: 420,
      maxMinutes: 540,
    };
  }

  private calculateBMR(
    weight: number,
    height: number,
    age: number,
    gender: string,
  ): number {
    const base = 10 * weight + 6.25 * height - 5 * age;

    return gender === 'female' ? base - 161 : base + 5;
  }

  private calculateTDEE(bmr: number, activityLevel: string): number {
    const multipliers: Record<string, number> = {
      low: 1.2,
      medium: 1.55,
      high: 1.9,
    };

    return bmr * (multipliers[activityLevel] ?? 1.2);
  }

  private adjustForGoal(tdee: number, goal: string): number {
    const adjustments: Record<string, number> = {
      lose: 0.8,
      gain: 1.15,
      maintain: 1.0,
    };

    return tdee * (adjustments[goal] ?? 1.0);
  }

  private calculateProtein(weight: number, goal: string): number {
    const perKg: Record<string, number> = {
      lose: 2.0,
      gain: 2.0,
      maintain: 1.6,
    };

    return weight * (perKg[goal] ?? 1.6);
  }

  private async findByUserIdSafe(
    userId: string,
    executor: Pick<typeof db, 'select'> = db,
  ) {
    const [goals] = await executor
      .select()
      .from(userGoals)
      .where(eq(userGoals.userId, userId))
      .limit(1);

    return goals;
  }
}
