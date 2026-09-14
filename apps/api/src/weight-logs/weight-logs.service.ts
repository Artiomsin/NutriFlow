import { Injectable } from '@nestjs/common';
import { db } from '../db/db';
import { weightLogs } from '../db/schema/weightLogs';
import { eq, and, gte, lte } from 'drizzle-orm';
import { invalidateAnalyticsCache } from '../redis';
import type {
  CreateWeightLogDto,
  ListWeightLogsDto,
} from './weight-logs.schema';

@Injectable()
export class WeightLogsService {
  async record(userId: string, data: CreateWeightLogDto) {
    const entryDate = data.date ?? this.toDateStr(new Date());

    const [log] = await db
      .insert(weightLogs)
      .values({
        userId,
        weightKg: String(data.weightKg),
        entryDate,
        source: 'manual',
      })
      .onConflictDoUpdate({
        target: [weightLogs.userId, weightLogs.entryDate],
        set: {
          weightKg: String(data.weightKg),
          source: 'manual',
          updatedAt: new Date(),
        },
      })
      .returning();

    await invalidateAnalyticsCache(userId);

    return log;
  }

  async findByRange(userId: string, query: ListWeightLogsDto = {}) {
    const conditions = [eq(weightLogs.userId, userId)];

    if (query.from) {
      conditions.push(gte(weightLogs.entryDate, query.from));
    }
    if (query.to) {
      conditions.push(lte(weightLogs.entryDate, query.to));
    }

    return db
      .select({
        id: weightLogs.id,
        weightKg: weightLogs.weightKg,
        entryDate: weightLogs.entryDate,
        source: weightLogs.source,
      })
      .from(weightLogs)
      .where(and(...conditions))
      .orderBy(weightLogs.entryDate);
  }

  async remove(userId: string, date: string) {
    await db
      .delete(weightLogs)
      .where(
        and(
          eq(weightLogs.userId, userId),
          eq(weightLogs.entryDate, date),
        ),
      );

    await invalidateAnalyticsCache(userId);

    return { message: 'Weight log removed' };
  }

  private toDateStr(date: Date): string {
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
  }
}