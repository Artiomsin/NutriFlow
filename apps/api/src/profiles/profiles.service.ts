import {
  Injectable,
  NotFoundException,
  ConflictException,
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
    const existing = await this.findByUserIdSafe(data.userId);

    if (existing) {
      throw new ConflictException('Profile already exists');
    }

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
      })
      .returning();

    try {
      await this.goalsService.calculate(data.userId);
    } catch (e) {
      console.error('Goals calculation skipped:', (e as Error).message);
    }

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
        goal: data.goal ?? existing.goal,
        activityLevel: data.activityLevel ?? existing.activityLevel,
        updatedAt: new Date(),
      })
      .where(eq(userProfiles.userId, userId))
      .returning();


    try {
      await this.goalsService.calculate(userId);
    } catch (e) {
      console.error('Goals calculation skipped:', (e as Error).message);
    }

    
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

  async findAll() {
    return db
      .select()
      .from(userProfiles);
  }
  
}