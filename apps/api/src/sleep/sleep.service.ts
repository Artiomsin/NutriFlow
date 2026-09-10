import { Injectable } from '@nestjs/common';
import { db } from '../db/db';
import { userSleep } from '../db/schema/userSleep';
import { and, eq, gte, lte, desc, count, notInArray } from 'drizzle-orm';
import type { SyncSleepDto } from './sleep.schema';

@Injectable()
export class SleepService {

  async sync(userId: string, dto: SyncSleepDto) {
    let synced = 0;
    await db.transaction(async (tx) => {
      for (const n of dto.nights) {
        const values = {
          userId,
          startDate: new Date(n.startDate),
          endDate: new Date(n.endDate),
          timeInBedSeconds: n.timeInBedSeconds != null ? String(n.timeInBedSeconds) : null,
          asleepSeconds: n.asleepSeconds != null ? String(n.asleepSeconds) : null,
          awakeSeconds: n.awakeSeconds != null ? String(n.awakeSeconds) : null,
          coreSeconds: n.coreSeconds != null ? String(n.coreSeconds) : null,
          deepSeconds: n.deepSeconds != null ? String(n.deepSeconds) : null,
          remSeconds: n.remSeconds != null ? String(n.remSeconds) : null,
          unspecifiedSeconds: n.unspecifiedSeconds != null ? String(n.unspecifiedSeconds) : null,
          awakenings: n.awakenings ?? null,
          onsetLatencySeconds: n.onsetLatencySeconds != null ? String(n.onsetLatencySeconds) : null,
          efficiency: n.efficiency != null ? String(n.efficiency) : null,
          segmentCount: n.segmentCount ?? null,
          heartRateAvg: n.heartRateAvg != null ? String(n.heartRateAvg) : null,
          sources: n.sources ?? {},
          nightMetrics: n.nightMetrics ?? {},
          source: 'healthkit',
        };
        await tx
          .insert(userSleep)
          .values(values)
          .onConflictDoUpdate({
            target: [userSleep.userId, userSleep.startDate],
            set: {
              endDate: new Date(n.endDate),
              timeInBedSeconds: n.timeInBedSeconds != null ? String(n.timeInBedSeconds) : null,
              asleepSeconds: n.asleepSeconds != null ? String(n.asleepSeconds) : null,
              awakeSeconds: n.awakeSeconds != null ? String(n.awakeSeconds) : null,
              coreSeconds: n.coreSeconds != null ? String(n.coreSeconds) : null,
              deepSeconds: n.deepSeconds != null ? String(n.deepSeconds) : null,
              remSeconds: n.remSeconds != null ? String(n.remSeconds) : null,
              unspecifiedSeconds: n.unspecifiedSeconds != null ? String(n.unspecifiedSeconds) : null,
              awakenings: n.awakenings ?? null,
              onsetLatencySeconds: n.onsetLatencySeconds != null ? String(n.onsetLatencySeconds) : null,
              efficiency: n.efficiency != null ? String(n.efficiency) : null,
              segmentCount: n.segmentCount ?? null,
              heartRateAvg: n.heartRateAvg != null ? String(n.heartRateAvg) : null,
              sources: n.sources ?? {},
              nightMetrics: n.nightMetrics ?? {},
              source: 'healthkit',
            },
          });
        synced += 1;
      }
    });
    return { synced };
  }

  async deleteMissing(userId: string, startDate: string, startDates: string[]) {
    const windowStart = new Date(startDate);
    const kept = startDates.map((d) => new Date(d));
    const res = await db
      .delete(userSleep)
      .where(
        and(
          eq(userSleep.userId, userId),
          gte(userSleep.startDate, windowStart),
          kept.length > 0 ? notInArray(userSleep.startDate, kept) : undefined,
        ),
      )
      .returning({ id: userSleep.id });
    return { deleted: res.length };
  }

  async getHistory(userId: string, from?: string, to?: string, limit = 200, offset = 0) {
    const conds = [eq(userSleep.userId, userId)];
    if (from) {
      conds.push(gte(userSleep.startDate, new Date(`${from}T00:00:00.000Z`)));
    }
    if (to) {
      conds.push(lte(userSleep.startDate, new Date(`${to}T23:59:59.999Z`)));
    }

    const where = and(...conds);
    const [rows, countRows] = await Promise.all([
      db
        .select()
        .from(userSleep)
        .where(where)
        .orderBy(desc(userSleep.startDate))
        .limit(limit)
        .offset(offset),
      db
        .select({ count: count() })
        .from(userSleep)
        .where(where),
    ]);
    const total = countRows[0]?.count ?? 0;

    return {
      total,
      nights: rows.map((r) => ({
        startDate: r.startDate.toISOString(),
        endDate: r.endDate.toISOString(),
        timeInBedSeconds: r.timeInBedSeconds != null ? Number(r.timeInBedSeconds) : null,
        asleepSeconds: r.asleepSeconds != null ? Number(r.asleepSeconds) : null,
        awakeSeconds: r.awakeSeconds != null ? Number(r.awakeSeconds) : null,
        coreSeconds: r.coreSeconds != null ? Number(r.coreSeconds) : null,
        deepSeconds: r.deepSeconds != null ? Number(r.deepSeconds) : null,
        remSeconds: r.remSeconds != null ? Number(r.remSeconds) : null,
        unspecifiedSeconds: r.unspecifiedSeconds != null ? Number(r.unspecifiedSeconds) : null,
        awakenings: r.awakenings,
        onsetLatencySeconds: r.onsetLatencySeconds != null ? Number(r.onsetLatencySeconds) : null,
        efficiency: r.efficiency != null ? Number(r.efficiency) : null,
        segmentCount: r.segmentCount,
        heartRateAvg: r.heartRateAvg != null ? Number(r.heartRateAvg) : null,
        sources: r.sources ?? {},
        nightMetrics: r.nightMetrics ?? {},
      })),
    };
  }
}