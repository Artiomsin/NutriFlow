import { Injectable, NotFoundException } from '@nestjs/common';
import { db } from '../db/db';
import { waterEntries } from '../db/schema/waterEntries';
import { dailySummary } from '../db/schema/dailySummary';
import { eq, and, sql } from 'drizzle-orm';
import type { CreateWaterEntryDto } from './water-tracking.schema';

@Injectable()
export class WaterTrackingService {async create(userId: string, dto: CreateWaterEntryDto) {
    const [entry] = await db
      .insert(waterEntries)
      .values({
        userId,
        amountMl: dto.amountMl,
      })
      .returning();

    await this.recalculateDailyWater(userId);

    return entry;
  }

  async getToday(userId: string) {
    return db
      .select()
      .from(waterEntries)
      .where(
        and(
          eq(waterEntries.userId, userId),
          sql`DATE(${waterEntries.createdAt}) = CURRENT_DATE`,
        ),
      );
  }

  async delete(userId: string, id: string) {
    const [deleted] = await db
      .delete(waterEntries)
      .where(
        and(
          eq(waterEntries.id, id),
          eq(waterEntries.userId, userId),
        ),
      )
      .returning();

    if (!deleted) {
      throw new NotFoundException('Water entry not found');
    }

    await this.recalculateDailyWater(userId);

    return { message: 'Deleted' };
  }

  // =========================
  // DAILY SUMMARY UPDATE
  // =========================

  private async recalculateDailyWater(userId: string) {
    const entries = await db
      .select()
      .from(waterEntries)
      .where(
        and(
          eq(waterEntries.userId, userId),
          sql`DATE(${waterEntries.createdAt}) = CURRENT_DATE`,
        ),
      );

    const totalWaterMl = entries.reduce(
      (acc, e) => acc + e.amountMl,
      0,
    );

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const existing = await db
      .select()
      .from(dailySummary)
      .where(
        and(
          eq(dailySummary.userId, userId),
          eq(dailySummary.date, today),
        ),
      )
      .limit(1);

    if (existing.length === 0) {
      await db.insert(dailySummary).values({
        userId,
        date: today,
        totalCalories: 0,
        totalProtein: 0,
        totalFat: 0,
        totalCarbs: 0,
        totalWaterMl,
      });

      return;
    }

    await db
      .update(dailySummary)
      .set({
        totalWaterMl,
      })
      .where(
        and(
          eq(dailySummary.userId, userId),
          eq(dailySummary.date, today),
        ),
      );
  }
}
