import { Injectable } from '@nestjs/common';
import { db } from '../db/db';
import { dailySummary } from '../db/schema/dailySummary';
import { foodEntries } from '../db/schema/foodEntries';
import { foods } from '../db/schema/foods';
import { foodCategories } from '../db/schema/foodCategories';
import { waterEntries } from '../db/schema/waterEntries';

import { eq, and, sql } from 'drizzle-orm';

@Injectable()
export class DailySummaryService {

  async adjust(userId: string, delta: {
    calories?: number;
    protein?: number;
    fat?: number;
    carbs?: number;
    waterMl?: number;
    date?: string;
  }) {
    const c = delta.calories ?? 0;
    const p = delta.protein ?? 0;
    const f = delta.fat ?? 0;
    const ca = delta.carbs ?? 0;
    const w = delta.waterMl ?? 0;
    const dateClause = delta.date ? sql`${delta.date}::date` : sql`CURRENT_DATE`;

    if (c === 0 && p === 0 && f === 0 && ca === 0 && w === 0) return;

    const allNegative = c <= 0 && p <= 0 && f <= 0 && ca <= 0 && w <= 0;

    if (allNegative) {
      const [existing] = await db
        .select({ id: dailySummary.id })
        .from(dailySummary)
        .where(
          and(
            eq(dailySummary.userId, userId),
            eq(dailySummary.date, dateClause),
          ),
        )
        .limit(1);

      if (!existing) return;
    }

    const cols = dailySummary;

    await db
      .insert(dailySummary)
      .values({
        userId,
        date: dateClause,
        totalCalories: Math.max(c, 0),
        totalProtein: Math.max(p, 0),
        totalFat: Math.max(f, 0),
        totalCarbs: Math.max(ca, 0),
        totalWaterMl: Math.max(w, 0),
      })
      .onConflictDoUpdate({
        target: [dailySummary.userId, dailySummary.date],
        set: {
          totalCalories: sql`GREATEST(0, ${cols.totalCalories} + ${c})`,
          totalProtein: sql`GREATEST(0, ${cols.totalProtein} + ${p})`,
          totalFat: sql`GREATEST(0, ${cols.totalFat} + ${f})`,
          totalCarbs: sql`GREATEST(0, ${cols.totalCarbs} + ${ca})`,
          totalWaterMl: sql`GREATEST(0, ${cols.totalWaterMl} + ${w})`,
        },
      });
  }

  async findToday(userId: string, dateStr?: string) {
    const dateClause = dateStr ? sql`${dateStr}::date` : sql`CURRENT_DATE`;
    const [summary] = await db
      .select()
      .from(dailySummary)
      .where(
        and(
          eq(dailySummary.userId, userId),
          eq(dailySummary.date, dateClause),
        ),
      )
      .limit(1);

    return summary ?? this.empty(dateStr ? new Date(dateStr + 'T00:00:00') : new Date());
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

  async findTodayDashboard(userId: string, dateStr?: string) {
    const dateClause = dateStr ? sql`${dateStr}::date` : sql`CURRENT_DATE`;
    const [summary] = await db
      .select()
      .from(dailySummary)
      .where(
        and(
          eq(dailySummary.userId, userId),
          eq(dailySummary.date, dateClause),
        ),
      )
      .limit(1);

    const [food, water] = await Promise.all([
      db
        .select({
          id: foodEntries.id,
          userId: foodEntries.userId,
          foodId: foodEntries.foodId,
          name: foodEntries.name,
          grams: foodEntries.grams,
          calories: foodEntries.calories,
          protein: foodEntries.protein,
          fat: foodEntries.fat,
          carbs: foodEntries.carbs,
          createdAt: foodEntries.createdAt,
          updatedAt: foodEntries.updatedAt,
          categoryName: foodCategories.name,
          imageUrl: sql`COALESCE(${foodEntries.imageUrl}, ${foods.imageUrl})`,
        })
        .from(foodEntries)
        .leftJoin(foods, eq(foodEntries.foodId, foods.id))
        .leftJoin(foodCategories, eq(foods.categoryId, foodCategories.id))
        .where(
          and(
            eq(foodEntries.userId, userId),
            eq(foodEntries.entryDate, dateClause),
          ),
        ),
      db
        .select()
        .from(waterEntries)
        .where(
          and(
            eq(waterEntries.userId, userId),
            eq(waterEntries.entryDate, dateClause),
          ),
        ),
    ]);

    return {
      dailySummary: summary ?? this.empty(dateStr ? new Date(dateStr + 'T00:00:00') : new Date()),
      foodEntries: food,
      waterEntries: water,
    };
  }

  private empty(date: Date = new Date()) {
    return {
      id: null,
      date,
      totalCalories: 0,
      totalProtein: 0,
      totalFat: 0,
      totalCarbs: 0,
      totalWaterMl: 0,
    };
  }
}