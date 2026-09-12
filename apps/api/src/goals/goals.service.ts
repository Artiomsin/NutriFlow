import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { db } from '../db/db';
import { userGoals } from '../db/schema/userGoals';
import { userProfiles } from '../db/schema/userProfiles';
import { eq } from 'drizzle-orm';
import type { UpdateGoalsDto } from './goals.schema';
import { invalidateAnalyticsCache } from '../redis';

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
          source: 'manual',
          updatedAt: new Date(),
        })
        .where(eq(userGoals.userId, userId))
        .returning();

      await invalidateAnalyticsCache(userId);

      return goals;
    }

    const [goals] = await db
      .insert(userGoals)
      .values({
        userId,
        ...data,
        source: 'manual',
      })
      .returning();

    await invalidateAnalyticsCache(userId);

    return goals;
  }

  async calculate(userId: string) {
    const [profile] = await db
      .select()
      .from(userProfiles)
      .where(eq(userProfiles.userId, userId))
      .limit(1);

    if (!profile) {
      throw new NotFoundException('Profile not found');
    }

    const {
      weight,
      height,
      age,
      gender,
      goal,
      activityLevel,
    } = profile;

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

    const carbs =
      (goalCalories - proteinCals - fatCals) / 4;

    const waterMultipliers: Record<string, number> = {
      low: 30,
      medium: 35,
      high: 40,
    };

    const water =
      weight * (waterMultipliers[activityLevel] ?? 35);

    // Activity / workout / sleep
    const activityGoals =
      this.calculateActivityGoals(activityLevel);

    const workoutGoals =
      this.calculateWorkoutGoals(activityLevel);

    const sleepGoals =
      this.calculateSleepGoals();

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

    const existing = await this.findByUserIdSafe(userId);

    if (existing) {
      if (existing.source === 'manual') {
        const merged = {
          dailyCaloriesGoal:
            existing.dailyCaloriesGoal ??
            calculated.dailyCaloriesGoal,

          dailyProteinGoal:
            existing.dailyProteinGoal ??
            calculated.dailyProteinGoal,

          dailyFatGoal:
            existing.dailyFatGoal ??
            calculated.dailyFatGoal,

          dailyCarbsGoal:
            existing.dailyCarbsGoal ??
            calculated.dailyCarbsGoal,

          dailyWaterGoal:
            existing.dailyWaterGoal ??
            calculated.dailyWaterGoal,

          dailyStepsGoal:
            existing.dailyStepsGoal ??
            calculated.dailyStepsGoal,

          dailyActiveCaloriesGoal:
            existing.dailyActiveCaloriesGoal ??
            calculated.dailyActiveCaloriesGoal,

          weeklyWorkoutsGoal:
            existing.weeklyWorkoutsGoal ??
            calculated.weeklyWorkoutsGoal,

          weeklyWorkoutMinutesGoal:
            existing.weeklyWorkoutMinutesGoal ??
            calculated.weeklyWorkoutMinutesGoal,

          nightlySleepMinMinutes:
            existing.nightlySleepMinMinutes ??
            calculated.nightlySleepMinMinutes,

          nightlySleepMaxMinutes:
            existing.nightlySleepMaxMinutes ??
            calculated.nightlySleepMaxMinutes,

          source: 'manual' as const,
          updatedAt: new Date(),
        };

        const [goals] = await db
          .update(userGoals)
          .set(merged)
          .where(eq(userGoals.userId, userId))
          .returning();

        await invalidateAnalyticsCache(userId);

        return goals;
      }

      const [goals] = await db
        .update(userGoals)
        .set({
          ...calculated,
          source: 'auto',
          updatedAt: new Date(),
        })
        .where(eq(userGoals.userId, userId))
        .returning();

      await invalidateAnalyticsCache(userId);

      return goals;
    }

    const [goals] = await db
      .insert(userGoals)
      .values({
        userId,
        ...calculated,
        source: 'auto',
      })
      .returning();

    await invalidateAnalyticsCache(userId);

    return goals;
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

    return (
      goals[activityLevel as keyof typeof goals] ??
      goals.medium
    );
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

    return (
      goals[activityLevel as keyof typeof goals] ??
      goals.medium
    );
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
    const base =
      10 * weight +
      6.25 * height -
      5 * age;

    return gender === 'female'
      ? base - 161
      : base + 5;
  }

  private calculateTDEE(
    bmr: number,
    activityLevel: string,
  ): number {
    const multipliers: Record<string, number> = {
      low: 1.2,
      medium: 1.55,
      high: 1.9,
    };

    return (
      bmr *
      (multipliers[activityLevel] ?? 1.2)
    );
  }

  private adjustForGoal(
    tdee: number,
    goal: string,
  ): number {
    const adjustments: Record<string, number> = {
      lose: 0.8,
      gain: 1.15,
      maintain: 1.0,
    };

    return (
      tdee *
      (adjustments[goal] ?? 1.0)
    );
  }

  private calculateProtein(
    weight: number,
    goal: string,
  ): number {
    const perKg: Record<string, number> = {
      lose: 2.0,
      gain: 2.0,
      maintain: 1.6,
    };

    return (
      weight *
      (perKg[goal] ?? 1.6)
    );
  }

  private async findByUserIdSafe(userId: string) {
    const [goals] = await db
      .select()
      .from(userGoals)
      .where(eq(userGoals.userId, userId))
      .limit(1);

    return goals;
  }
}