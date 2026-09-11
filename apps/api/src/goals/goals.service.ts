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
    const { weight, height, age, gender, goal, activityLevel } = profile;
    if (!weight || !height || !age || !gender || !goal || !activityLevel) {
      throw new BadRequestException(
        'Not enough profile data to calculate goals. Provide weight, height, age, gender, goal and activityLevel.',
      );
    }
    const bmr = this.calculateBMR(weight, height, age, gender);
    const tdee = this.calculateTDEE(bmr, activityLevel);
    const goalCalories = this.adjustForGoal(tdee, goal);
    const protein = this.calculateProtein(weight, goal);
    const fat = (goalCalories * 0.25) / 9;
    const proteinCals = protein * 4;
    const fatCals = fat * 9;
    const carbs = (goalCalories - proteinCals - fatCals) / 4;
    const waterMultipliers: Record<string, number> = { low: 30, medium: 35, high: 40 };
    const water = weight * (waterMultipliers[activityLevel] ?? 35);
    const calculated = {
      dailyCaloriesGoal: Math.round(goalCalories),
      dailyProteinGoal: Math.round(protein),
      dailyFatGoal: Math.round(fat),
      dailyCarbsGoal: Math.round(carbs),
      dailyWaterGoal: Math.round(water),
    };
    const existing = await this.findByUserIdSafe(userId);
    if (existing) {
      if (existing.source === 'manual') {
        const merged = {
          dailyCaloriesGoal: existing.dailyCaloriesGoal ?? calculated.dailyCaloriesGoal,
          dailyProteinGoal: existing.dailyProteinGoal ?? calculated.dailyProteinGoal,
          dailyFatGoal: existing.dailyFatGoal ?? calculated.dailyFatGoal,
          dailyCarbsGoal: existing.dailyCarbsGoal ?? calculated.dailyCarbsGoal,
          dailyWaterGoal: existing.dailyWaterGoal ?? calculated.dailyWaterGoal,
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
        .set({ ...calculated, source: 'auto', updatedAt: new Date() })
        .where(eq(userGoals.userId, userId))
        .returning();
      await invalidateAnalyticsCache(userId);
      return goals;
    }
    const [goals] = await db
      .insert(userGoals)
      .values({ userId, ...calculated, source: 'auto' })
      .returning();
    await invalidateAnalyticsCache(userId);
    return goals;
  }
  private calculateBMR(weight: number, height: number, age: number, gender: string): number {
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
  private async findByUserIdSafe(userId: string) {
    const [goals] = await db
      .select()
      .from(userGoals)
      .where(eq(userGoals.userId, userId))
      .limit(1);
    return goals;
  }
}