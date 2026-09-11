import { Injectable } from '@nestjs/common';
import { db } from '../db/db';
import { userWorkouts } from '../db/schema/userWorkouts';
import { and, eq, gte, lte, desc, count, notInArray } from 'drizzle-orm';
import type { SyncWorkoutsDto } from './workouts.schema';

@Injectable()
export class WorkoutsService {

  async sync(userId: string, dto: SyncWorkoutsDto) {
    let synced = 0;
    await db.transaction(async (tx) => {
      for (const w of dto.workouts) {
        const values = {
          userId,
          healthKitWorkoutId: w.healthKitWorkoutId,
          type: w.type,
          startDate: new Date(w.startDate),
          endDate: new Date(w.endDate),
          durationSeconds: String(w.durationSeconds),
          caloriesBurned: w.caloriesBurned != null ? String(w.caloriesBurned) : null,
          distanceMeters: w.distanceMeters != null ? String(w.distanceMeters) : null,
          heartRateAvg: w.heartRateAvg != null ? String(w.heartRateAvg) : null,
          heartRateMax: w.heartRateMax != null ? String(w.heartRateMax) : null,
          heartRateMin: w.heartRateMin != null ? String(w.heartRateMin) : null,
          avgSpeedMps: w.avgSpeedMps != null ? String(w.avgSpeedMps) : null,
          maxSpeedMps: w.maxSpeedMps != null ? String(w.maxSpeedMps) : null,
          avgCadence: w.avgCadence != null ? String(w.avgCadence) : null,
          maxCadence: w.maxCadence != null ? String(w.maxCadence) : null,
          avgPowerWatts: w.avgPowerWatts != null ? String(w.avgPowerWatts) : null,
          maxPowerWatts: w.maxPowerWatts != null ? String(w.maxPowerWatts) : null,
          elevationGainMeters: w.elevationGainMeters != null ? String(w.elevationGainMeters) : null,
          steps: w.steps ?? null,
          indoor: w.indoor ?? null,
          details: w.details ?? {},
        };
        await tx
          .insert(userWorkouts)
          .values(values)
          .onConflictDoUpdate({
            target: [userWorkouts.userId, userWorkouts.healthKitWorkoutId],
            set: {
              type: w.type,
              startDate: new Date(w.startDate),
              endDate: new Date(w.endDate),
              durationSeconds: String(w.durationSeconds),
              caloriesBurned: w.caloriesBurned != null ? String(w.caloriesBurned) : null,
              distanceMeters: w.distanceMeters != null ? String(w.distanceMeters) : null,
              heartRateAvg: w.heartRateAvg != null ? String(w.heartRateAvg) : null,
              heartRateMax: w.heartRateMax != null ? String(w.heartRateMax) : null,
              heartRateMin: w.heartRateMin != null ? String(w.heartRateMin) : null,
              avgSpeedMps: w.avgSpeedMps != null ? String(w.avgSpeedMps) : null,
              maxSpeedMps: w.maxSpeedMps != null ? String(w.maxSpeedMps) : null,
              avgCadence: w.avgCadence != null ? String(w.avgCadence) : null,
              maxCadence: w.maxCadence != null ? String(w.maxCadence) : null,
              avgPowerWatts: w.avgPowerWatts != null ? String(w.avgPowerWatts) : null,
              maxPowerWatts: w.maxPowerWatts != null ? String(w.maxPowerWatts) : null,
              elevationGainMeters: w.elevationGainMeters != null ? String(w.elevationGainMeters) : null,
              steps: w.steps ?? null,
              indoor: w.indoor ?? null,
              details: w.details ?? {},
            },
          });
        synced += 1;
      }
    });
    return { synced };
  }

  async deleteMissing(userId: string, startDate: string, healthKitWorkoutIds: string[]) {
    const res = await db
      .delete(userWorkouts)
      .where(
        and(
          eq(userWorkouts.userId, userId),
          gte(userWorkouts.startDate, new Date(startDate)),
          healthKitWorkoutIds.length > 0
            ? notInArray(userWorkouts.healthKitWorkoutId, healthKitWorkoutIds)
            : undefined,
        ),
      )
      .returning({ id: userWorkouts.id });
    return { deleted: res.length };
  }

  async getHistory(userId: string, from?: string, to?: string, limit = 200, offset = 0) {
    const conds = [eq(userWorkouts.userId, userId)];
    if (from) {
      conds.push(gte(userWorkouts.startDate, new Date(`${from}T00:00:00.000Z`)));
    }
    if (to) {
      conds.push(lte(userWorkouts.startDate, new Date(`${to}T23:59:59.999Z`)));
    }

    const where = and(...conds);
    const [rows, countRows] = await Promise.all([
      db
        .select()
        .from(userWorkouts)
        .where(where)
        .orderBy(desc(userWorkouts.startDate))
        .limit(limit)
        .offset(offset),
      db
        .select({ count: count() })
        .from(userWorkouts)
        .where(where),
    ]);
    const total = countRows[0]?.count ?? 0;

    return {
      total,
      workouts: rows.map((r) => ({
        healthKitWorkoutId: r.healthKitWorkoutId,
        type: r.type,
        startDate: r.startDate.toISOString(),
        endDate: r.endDate.toISOString(),
        durationSeconds: Number(r.durationSeconds ?? 0),
        caloriesBurned: r.caloriesBurned != null ? Number(r.caloriesBurned) : null,
        distanceMeters: r.distanceMeters != null ? Number(r.distanceMeters) : null,
        heartRateAvg: r.heartRateAvg != null ? Number(r.heartRateAvg) : null,
        heartRateMax: r.heartRateMax != null ? Number(r.heartRateMax) : null,
        heartRateMin: r.heartRateMin != null ? Number(r.heartRateMin) : null,
        avgSpeedMps: r.avgSpeedMps != null ? Number(r.avgSpeedMps) : null,
        maxSpeedMps: r.maxSpeedMps != null ? Number(r.maxSpeedMps) : null,
        avgCadence: r.avgCadence != null ? Number(r.avgCadence) : null,
        maxCadence: r.maxCadence != null ? Number(r.maxCadence) : null,
        avgPowerWatts: r.avgPowerWatts != null ? Number(r.avgPowerWatts) : null,
        maxPowerWatts: r.maxPowerWatts != null ? Number(r.maxPowerWatts) : null,
        elevationGainMeters: r.elevationGainMeters != null ? Number(r.elevationGainMeters) : null,
        steps: r.steps,
        indoor: r.indoor,
        details: r.details ?? {},
      })),
    };
  }
}