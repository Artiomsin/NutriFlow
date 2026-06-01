import { Injectable, NotFoundException } from '@nestjs/common';
import { db } from '../db/db';
import { foodEntries } from '../db/schema/foodEntries';
import { dailySummary } from '../db/schema/dailySummary';
import { eq, and, sql } from 'drizzle-orm';
import type { CreateFoodEntryDto } from './food.schema';

@Injectable()
export class FoodService {
  async create(userId: string, data: CreateFoodEntryDto) {
    const [entry] = await db
      .insert(foodEntries)
      .values({
        userId,
        name: data.name,
        calories: data.calories,
        protein: data.protein ?? 0,
        fat: data.fat ?? 0,
        carbs: data.carbs ?? 0,
      })
      .returning();

    await this.recalculateDailySummary(userId);

    return entry;
  }

  async getToday(userId: string) {
    return db
      .select()
      .from(foodEntries)
      .where(
        and(
          eq(foodEntries.userId, userId),
          sql`DATE(${foodEntries.createdAt}) = CURRENT_DATE`,
        ),
      );
  }

  async delete(userId: string, id: string) {
    const [deleted] = await db
      .delete(foodEntries)
      .where(
        and(
          eq(foodEntries.id, id),
          eq(foodEntries.userId, userId),
        ),
      )
      .returning();

    if (!deleted) {
      throw new NotFoundException('Food entry not found');
    }

    await this.recalculateDailySummary(userId);

    return { message: 'Deleted' };
  }


  private async recalculateDailySummary(userId: string) {
    const entries = await db
      .select()
      .from(foodEntries)
      .where(
        and(
          eq(foodEntries.userId, userId),
          sql`DATE(${foodEntries.createdAt}) = CURRENT_DATE`,
        ),
      );

    const totals = entries.reduce(
      (acc, e) => {
        acc.calories += e.calories;
        acc.protein += e.protein ?? 0;
        acc.fat += e.fat ?? 0;
        acc.carbs += e.carbs ?? 0;
        return acc;
      },
      { calories: 0, protein: 0, fat: 0, carbs: 0 },
    );

    const existing = await db
      .select()
      .from(dailySummary)
      .where(
        and(
          eq(dailySummary.userId, userId),
          sql`DATE(${dailySummary.date}) = CURRENT_DATE`,
        ),
      )
      .limit(1);

    if (existing.length === 0) {
      await db.insert(dailySummary).values({
        userId,
        date: sql`CURRENT_DATE`,
        totalCalories: totals.calories,
        totalProtein: totals.protein,
        totalFat: totals.fat,
        totalCarbs: totals.carbs,
        totalWaterMl: 0,
      });

      return;
    }

    await db
      .update(dailySummary)
      .set({
        totalCalories: totals.calories,
        totalProtein: totals.protein,
        totalFat: totals.fat,
        totalCarbs: totals.carbs,
      })
      .where(
        and(
          eq(dailySummary.userId, userId),
          sql`DATE(${dailySummary.date}) = CURRENT_DATE`,
        ),
      );
  }
}