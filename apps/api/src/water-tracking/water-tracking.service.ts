import { Injectable, NotFoundException } from '@nestjs/common';
import { db } from '../db/db';
import { waterEntries } from '../db/schema/waterEntries';
import { eq, and, sql } from 'drizzle-orm';
import { redis } from '../redis';
import { DailySummaryService } from '../daily-summary/daily-summary.service';
import type { CreateWaterEntryDto } from './water-tracking.schema';

@Injectable()
export class WaterTrackingService {

  constructor(private readonly dailySummaryService: DailySummaryService) {}

  async create(userId: string, dto: CreateWaterEntryDto) {
    const [entry] = await db
      .insert(waterEntries)
      .values({
        userId,
        amountMl: dto.amountMl,
      })
      .returning();

    await this.dailySummaryService.recalculate(userId);
    await this.invalidateAnalyticsCache(userId);

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

  async getByDate(userId: string, date: string) {
    return db
      .select()
      .from(waterEntries)
      .where(
        and(
          eq(waterEntries.userId, userId),
          sql`DATE(${waterEntries.createdAt}) = ${date}::date`,
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

    await this.dailySummaryService.recalculate(userId);
    await this.invalidateAnalyticsCache(userId);

    return { message: 'Deleted' };
  }

  private async invalidateAnalyticsCache(userId: string) {
    await redis.del(`analytics:${userId}:week`);
    await redis.del(`analytics:${userId}:month`);
  }
}
