import { Injectable } from '@nestjs/common';
import { db } from '../db/db';
import { dailySummary } from '../db/schema/dailySummary';
import { foodEntries } from '../db/schema/foodEntries';
import { waterEntries } from '../db/schema/waterEntries';

import { eq, and, sql } from 'drizzle-orm';

@Injectable()
export class DailySummaryService {

  async recalculate(userId: string) {
    const [foodRow] = await db
      .select({
        calories: sql<number>`COALESCE(SUM(${foodEntries.calories}), 0)`,
        protein: sql<number>`COALESCE(SUM(${foodEntries.protein}), 0)`,
        fat: sql<number>`COALESCE(SUM(${foodEntries.fat}), 0)`,
        carbs: sql<number>`COALESCE(SUM(${foodEntries.carbs}), 0)`,
      })
      .from(foodEntries)
      .where(
        and(
          eq(foodEntries.userId, userId),
          sql`DATE(${foodEntries.createdAt}) = CURRENT_DATE`,
        ),
      );

    const [waterRow] = await db
      .select({
        total: sql<number>`COALESCE(SUM(${waterEntries.amountMl}), 0)`,
      })
      .from(waterEntries)
      .where(
        and(
          eq(waterEntries.userId, userId),
          sql`DATE(${waterEntries.createdAt}) = CURRENT_DATE`,
        ),
      );

    const food = foodRow ?? { calories: 0, protein: 0, fat: 0, carbs: 0 };
    const water = waterRow?.total ?? 0;

    await db
      .insert(dailySummary)
      .values({
        userId,
        date: sql`CURRENT_DATE`,
        totalCalories: food.calories,
        totalProtein: food.protein,
        totalFat: food.fat,
        totalCarbs: food.carbs,
        totalWaterMl: water,
      })
      .onConflictDoUpdate({
        target: [dailySummary.userId, dailySummary.date],
        set: {
          totalCalories: food.calories,
          totalProtein: food.protein,
          totalFat: food.fat,
          totalCarbs: food.carbs,
          totalWaterMl: water,
        },
      });
  }

  async findToday(userId: string) {
    const [summary] = await db
      .select()
      .from(dailySummary)
      .where(
        and(
          eq(dailySummary.userId, userId),
          eq(dailySummary.date, sql`CURRENT_DATE`),
        ),
      )
      .limit(1);

    return summary ?? this.empty();
  }

  async findByDate(userId: string, date?: string) {
    if (!date) return this.findToday(userId);

    const [summary] = await db
      .select()
      .from(dailySummary)
      .where(
        and(
          eq(dailySummary.userId, userId),
          eq(dailySummary.date, sql`${date}::date`),
        ),
      )
      .limit(1);

    const target = new Date(date + 'T00:00:00');
    return summary ?? this.empty(target);
  }

  async findRange(userId: string, from: string, to: string) {
    const result = await db
      .select()
      .from(dailySummary)
      .where(
        and(
          eq(dailySummary.userId, userId),
          sql`${dailySummary.date} >= ${from}::date`,
          sql`${dailySummary.date} <= ${to}::date`,
        ),
      )
      .orderBy(dailySummary.date);

    return result;
  }

  async findTodayDashboard(userId: string) {
    const [summary] = await db
      .select()
      .from(dailySummary)
      .where(
        and(
          eq(dailySummary.userId, userId),
          eq(dailySummary.date, sql`CURRENT_DATE`),
        ),
      )
      .limit(1);

    const [food, water] = await Promise.all([
      db
        .select()
        .from(foodEntries)
        .where(
          and(
            eq(foodEntries.userId, userId),
            sql`DATE(${foodEntries.createdAt}) = CURRENT_DATE`,
          ),
        ),
      db
        .select()
        .from(waterEntries)
        .where(
          and(
            eq(waterEntries.userId, userId),
            sql`DATE(${waterEntries.createdAt}) = CURRENT_DATE`,
          ),
        ),
    ]);

    return {
      dailySummary: summary ?? this.empty(),
      foodEntries: food,
      waterEntries: water,
    };
  }

  private empty(date: Date = new Date()) {
    return {
      date,
      totalCalories: 0,
      totalProtein: 0,
      totalFat: 0,
      totalCarbs: 0,
      totalWaterMl: 0,
    };
  }
}