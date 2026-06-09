import { Injectable, NotFoundException } from '@nestjs/common';
import { db } from '../db/db';
import { foodEntries } from '../db/schema/foodEntries';
import { eq, and, sql } from 'drizzle-orm';
import { redis } from '../redis';
import { DailySummaryService } from '../daily-summary/daily-summary.service';
import type { CreateFoodEntryDto } from './food.schema';

@Injectable()
export class FoodService {

  constructor(private readonly dailySummaryService: DailySummaryService) {}

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

    await this.dailySummaryService.recalculate(userId);
    await this.invalidateAnalyticsCache(userId);

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

    await this.dailySummaryService.recalculate(userId);
    await this.invalidateAnalyticsCache(userId);

    return { message: 'Deleted' };
  }

  private async invalidateAnalyticsCache(userId: string) {
    await redis.del(`analytics:${userId}:week`);
    await redis.del(`analytics:${userId}:month`);
  }
}