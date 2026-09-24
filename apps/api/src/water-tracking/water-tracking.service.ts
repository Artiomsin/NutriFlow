import { Injectable, NotFoundException } from '@nestjs/common';
import { db } from '../db/db';
import { waterEntries } from '../db/schema/waterEntries';
import { eq, and, sql } from 'drizzle-orm';
import { invalidateAnalyticsCache } from '../redis';
import { DailySummaryService } from '../daily-summary/daily-summary.service';
import { currentUserDate } from '../common/time/user-date';
import type { CreateWaterEntryDto } from './water-tracking.schema';

@Injectable()
export class WaterTrackingService {

  constructor(private readonly dailySummaryService: DailySummaryService) {}

  async create(userId: string, dto: CreateWaterEntryDto) {
    const entryDate = dto.date ?? await currentUserDate(userId);
    const entry = await db.transaction(async (tx) => {
      const [created] = await tx
        .insert(waterEntries)
        .values({
          userId,
          amountMl: dto.amountMl,
          entryDate,
        })
        .returning();

      await this.dailySummaryService.adjust(
        userId,
        { waterMl: dto.amountMl, date: entryDate },
        tx,
      );

      return created;
    });

    await invalidateAnalyticsCache(userId);

    return entry;
  }

  async getToday(userId: string, dateStr?: string) {
    const date = dateStr ?? await currentUserDate(userId);
    const dateClause = sql`${date}::date`;
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
    const result = await db.transaction(async (tx) => {
      const [deleted] = await tx
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

      const deletedDate = deleted.entryDate ?? date ?? (deleted.createdAt instanceof Date
        ? deleted.createdAt.toISOString().split('T')[0]
        : undefined);

      await this.dailySummaryService.adjust(
        userId,
        { waterMl: -deleted.amountMl, date: deletedDate },
        tx,
      );

      return { message: 'Deleted' };
    });

    await invalidateAnalyticsCache(userId);

    return result;
  }

}
