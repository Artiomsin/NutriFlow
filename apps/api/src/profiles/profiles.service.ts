import {
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { db } from '../db/db';
import { userProfiles } from '../db/schema/userProfiles';
import { eq } from 'drizzle-orm';
import { GoalsService } from '../goals/goals.service';


import type {
  CreateProfileDto,
  UpdateProfileDto,
} from './profiles.schema';

@Injectable()
export class ProfilesService {
  constructor(private goalsService: GoalsService) {} 
  
  async create(data: CreateProfileDto & { userId: string }) {
    const [profile] = await db
      .insert(userProfiles)
      .values({
        userId: data.userId,
        weight: data.weight,
        height: data.height,
        age: data.age,
        gender: data.gender,
        goal: data.goal,
        activityLevel: data.activityLevel,
        preferredUnits: data.preferredUnits ?? { weight: 'metric', volume: 'metric', energy: 'kcal' },
      })
      .onConflictDoNothing({ target: userProfiles.userId })
      .returning();

    if (!profile) {
      const existing = await this.findByUserIdSafe(data.userId);
      if (!existing) {
        throw new Error('Profile creation failed');
      }
      await this.goalsService.calculate(data.userId);
      return existing;
    }

    await this.goalsService.calculate(data.userId);
    return profile;
  }

  async findByUserId(userId: string) {
    const profile = await this.findByUserIdSafe(userId);

    if (!profile) {
      throw new NotFoundException('Profile not found');
    }

    return profile;
  }

  async updateByUserId(userId: string, data: UpdateProfileDto) {
    const existing = await this.findByUserIdSafe(userId);

    if (!existing) {
      throw new NotFoundException('Profile not found');
    }

    const [profile] = await db
      .update(userProfiles)
      .set({
        weight: data.weight ?? existing.weight,
        height: data.height ?? existing.height,
        age: data.age ?? existing.age,
        gender: data.gender ?? existing.gender,
        goal: data.goal ?? existing.goal,
        activityLevel: data.activityLevel ?? existing.activityLevel,
        preferredUnits: data.preferredUnits ?? existing.preferredUnits as any,
        updatedAt: new Date(),
      })
      .where(eq(userProfiles.userId, userId))
      .returning();


    await this.goalsService.calculate(userId);
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

  private async findByUserIdSafe(userId: string) {
    const [profile] = await db
      .select()
      .from(userProfiles)
      .where(eq(userProfiles.userId, userId))
      .limit(1);

    return profile;
  }

  async findAll(limit = 50, offset = 0) {
    return db
      .select()
      .from(userProfiles)
      .limit(limit)
      .offset(offset);
  }
  
}