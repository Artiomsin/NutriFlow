import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { db } from '../db/db';
import { weightLogs } from '../db/schema/weightLogs';
import { userProfiles } from '../db/schema/userProfiles';
import { eq, and, desc, gte, lte, sql } from 'drizzle-orm';
import { GoalsService } from '../goals/goals.service';
import type {
  CreateWeightLogDto,
  ListWeightLogsDto,
} from './weight-logs.schema';
import { formatDateInTimeZone } from '../common/time/user-date';

@Injectable()
export class WeightLogsService {
  constructor(private readonly goalsService: GoalsService) {}

  async record(userId: string, data: CreateWeightLogDto) {
    const log = await db.transaction(async (tx) => {
      const [profile] = await tx
        .select({ timeZone: userProfiles.timeZone })
        .from(userProfiles)
        .where(eq(userProfiles.userId, userId))
        .limit(1);

      if (!profile) throw new NotFoundException('Profile not found');

      const today = formatDateInTimeZone(new Date(), profile.timeZone);
      const entryDate = data.date ?? today;
      const [recorded] = await tx
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
            // The onboarding point is the immutable baseline for its date.
            // A same-day correction may change its value, but must not make it
            // deletable and leave the user without any baseline weight.
            source: sql`case when ${weightLogs.source} = 'initial' then 'initial' else 'manual' end`,
            updatedAt: new Date(),
          },
        })
        .returning({
          id: weightLogs.id,
          weightKg: sql<number>`${weightLogs.weightKg}::float8`,
          entryDate: weightLogs.entryDate,
          source: weightLogs.source,
        });

      // A backfilled historical measurement belongs on the chart only. It must
      // not turn into the person's current weight or change today's targets.
      if (entryDate === today) {
        await tx
          .update(userProfiles)
          .set({ weight: data.weightKg, updatedAt: new Date() })
          .where(eq(userProfiles.userId, userId));

        // Custom/personalized targets remain protected by GoalsService; only
        // calculated fields are adjusted for the newly recorded current weight.
        await this.goalsService.calculate(userId, tx);
      }
      return recorded;
    });

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
        weightKg: sql<number>`${weightLogs.weightKg}::float8`,
        entryDate: weightLogs.entryDate,
        source: weightLogs.source,
      })
      .from(weightLogs)
      .where(and(...conditions))
      .orderBy(weightLogs.entryDate);
  }

  async remove(userId: string, date: string) {
    await db.transaction(async (tx) => {
      const [profile] = await tx
        .select({ timeZone: userProfiles.timeZone })
        .from(userProfiles)
        .where(eq(userProfiles.userId, userId))
        .limit(1);
      if (!profile) throw new NotFoundException('Profile not found');

      const [existing] = await tx
        .select({ source: weightLogs.source })
        .from(weightLogs)
        .where(and(eq(weightLogs.userId, userId), eq(weightLogs.entryDate, date)))
        .limit(1);

      if (existing?.source === 'initial') {
        throw new BadRequestException('The initial weight record cannot be deleted');
      }
      if (!existing) {
        throw new NotFoundException('Weight record not found');
      }

      await tx
        .delete(weightLogs)
        .where(
          and(
            eq(weightLogs.userId, userId),
            eq(weightLogs.entryDate, date),
          ),
        );

      const today = formatDateInTimeZone(new Date(), profile.timeZone);
      if (date === today && existing) {
        const [previous] = await tx
          .select({ weightKg: weightLogs.weightKg })
          .from(weightLogs)
          .where(and(eq(weightLogs.userId, userId), lte(weightLogs.entryDate, today)))
          .orderBy(desc(weightLogs.entryDate))
          .limit(1);

        if (previous) {
          await tx
            .update(userProfiles)
            .set({ weight: Number(previous.weightKg), updatedAt: new Date() })
            .where(eq(userProfiles.userId, userId));
          await this.goalsService.calculate(userId, tx);
        }
      }
    });

    return { message: 'Weight log removed' };
  }

}
