import {
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { db } from '../db/db';
import { userProfiles } from '../db/schema/userProfiles';
import { eq } from 'drizzle-orm';
import { GoalsService } from '../goals/goals.service';
import { weightLogs } from '../db/schema/weightLogs';
import { formatDateInTimeZone } from '../common/time/user-date';
import { invalidateAnalyticsCache } from '../redis';

import type {
  CreateProfileDto,
  UpdateProfileDto,
} from './profiles.schema';

@Injectable()
export class ProfilesService {
  constructor(
    private goalsService: GoalsService,
  ) {}
  
  async create(data: CreateProfileDto & { userId: string }) {
    const timeZone = data.timeZone ?? 'UTC';
    const initialDate = formatDateInTimeZone(new Date(), timeZone);

    const result = await db.transaction(async (tx) => {
      const [profile] = await tx
        .insert(userProfiles)
        .values({
          userId: data.userId,
          weight: data.weight,
          height: data.height,
          age: data.age,
          gender: data.gender,
          goal: data.goal,
          activityLevel: data.activityLevel,
          timeZone,
          preferredUnits: data.preferredUnits ?? { weight: 'metric', volume: 'metric', energy: 'kcal' },
        })
        .onConflictDoNothing({ target: userProfiles.userId })
        .returning();

      // POST is idempotent: an existing profile must not create a new initial log
      // or silently replace its calculated goals.
      if (!profile) {
        const [existing] = await tx
          .select()
          .from(userProfiles)
          .where(eq(userProfiles.userId, data.userId))
          .limit(1);
        if (!existing) throw new Error('Profile creation failed');
        return { profile: existing, created: false };
      }

      await tx.insert(weightLogs).values({
        userId: data.userId,
        weightKg: String(data.weight),
        entryDate: initialDate,
        source: 'initial',
      });

      await this.goalsService.calculate(data.userId, tx, false);
      return { profile, created: true };
    });

    if (result.created) await invalidateAnalyticsCache(data.userId);
    return result.profile;
  }

  async findByUserId(userId: string) {
    const profile = await this.findByUserIdSafe(userId);

    if (!profile) {
      throw new NotFoundException('Profile not found');
    }

    return profile;
  }

  async updateByUserId(userId: string, data: UpdateProfileDto) {
    const profile = await db.transaction(async (tx) => {
      const [existing] = await tx
        .select()
        .from(userProfiles)
        .where(eq(userProfiles.userId, userId))
        .limit(1);

      if (!existing) throw new NotFoundException('Profile not found');

      const [updated] = await tx
        .update(userProfiles)
        .set({
          weight: existing.weight,
          height: data.height ?? existing.height,
          age: data.age ?? existing.age,
          gender: data.gender ?? existing.gender,
          goal: data.goal ?? existing.goal,
          activityLevel: data.activityLevel ?? existing.activityLevel,
          timeZone: data.timeZone ?? existing.timeZone,
          preferredUnits: data.preferredUnits ?? existing.preferredUnits as any,
          updatedAt: new Date(),
        })
        .where(eq(userProfiles.userId, userId))
        .returning();

      await this.goalsService.calculate(userId, tx, false);
      return updated;
    });

    await invalidateAnalyticsCache(userId);
    return profile;
  }

  async deleteByUserId(userId: string) {
    const existing = await this.findByUserIdSafe(userId);

    if (!existing) {
      throw new NotFoundException('Profile not found');
    }

    await db
      .delete(userProfiles)
      .where(eq(userProfiles.userId, userId));

    return { message: 'Profile deleted' };
  }

  async updateTimeZone(userId: string, timeZone: string) {
    const [profile] = await db
      .update(userProfiles)
      .set({ timeZone, updatedAt: new Date() })
      .where(eq(userProfiles.userId, userId))
      .returning();

    if (!profile) throw new NotFoundException('Profile not found');
    await invalidateAnalyticsCache(userId);
    return profile;
  }

  private async findByUserIdSafe(userId: string) {
    const [profile] = await db
      .select()
      .from(userProfiles)
      .where(eq(userProfiles.userId, userId))
      .limit(1);

    return profile;
  }

}
