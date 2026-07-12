import { Injectable, NotFoundException } from '@nestjs/common';
import { db } from '../db/db';
import { waterEntries } from '../db/schema/waterEntries';
import { eq, and, sql } from 'drizzle-orm';
import { invalidateAnalyticsCache } from '../redis';
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
        entryDate: dto.date,
      })
      .returning();

    await this.dailySummaryService.adjust(userId, { waterMl: dto.amountMl, date: dto.date });
    await invalidateAnalyticsCache(userId);

    return entry;
  }

  async getToday(userId: string, dateStr?: string) {
    const dateClause = dateStr ? sql`${dateStr}::date` : sql`CURRENT_DATE`;
    return db
      .select()
      .from(waterEntries)
      .where(
        and(
          eq(waterEntries.userId, userId),
          eq(waterEntries.entryDate, dateClause),
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
          eq(waterEntries.entryDate, sql`${date}::date`),
        ),
      );
  }

  async delete(userId: string, id: string, date?: string) {
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

    const deletedDate = date ?? deleted.entryDate ?? (deleted.createdAt instanceof Date
      ? deleted.createdAt.toISOString().split('T')[0]
      : undefined);

    await this.dailySummaryService.adjust(userId, { waterMl: -deleted.amountMl, date: deletedDate });
    await invalidateAnalyticsCache(userId);

    return { message: 'Deleted' };
  }

}
