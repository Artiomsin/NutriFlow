import { randomUUID } from 'node:crypto';

import { users } from '../../src/db/schema/users';
import { userProfiles } from '../../src/db/schema/userProfiles';
import { foods } from '../../src/db/schema/foods';
import { foodCategories } from '../../src/db/schema/foodCategories';
import { dailyActivity } from '../../src/db/schema/dailyActivity';
import { dailySummary } from '../../src/db/schema/dailySummary';
import { userSleep } from '../../src/db/schema/userSleep';
import { userWorkouts } from '../../src/db/schema/userWorkouts';
import type { NewUserProfile } from '../../src/db/schema/userProfiles';
import type { NewDailyActivity } from '../../src/db/schema/dailyActivity';
import type { NewDailySummary } from '../../src/db/schema/dailySummary';
import type { NewUserSleep } from '../../src/db/schema/userSleep';
import type { NewUserWorkout } from '../../src/db/schema/userWorkouts';
import type { TestTx } from './db';

export async function createDailyActivity(
  tx: TestTx,
  userId: string,
  overrides: Partial<NewDailyActivity> & { date: string },
) {
  const [row] = await tx
    .insert(dailyActivity)
    .values({ userId, ...overrides })
    .returning();
  return row!;
}

export async function createDailySummary(
  tx: TestTx,
  userId: string,
  overrides: Partial<NewDailySummary> & { date: string },
) {
  const [row] = await tx
    .insert(dailySummary)
    .values({ userId, ...overrides })
    .returning();
  return row!;
}

export async function createSleepNight(
  tx: TestTx,
  userId: string,
  overrides: Partial<NewUserSleep> & {
    startDate: Date;
    endDate: Date;
    localDate: string;
  },
) {
  const [row] = await tx
    .insert(userSleep)
    .values({ userId, ...overrides })
    .returning();
  return row!;
}

export async function createWorkout(
  tx: TestTx,
  userId: string,
  overrides: Partial<NewUserWorkout> & {
    startDate: Date;
    endDate: Date;
    localDate: string;
  },
) {
  const [row] = await tx
    .insert(userWorkouts)
    .values({
      userId,
      healthKitWorkoutId: `HK-${randomUUID()}`,
      type: 'running',
      durationSeconds: '1800',
      ...overrides,
    })
    .returning();
  return row!;
}

/**
 * Shared fixtures for integration specs. Every helper writes through the test
 * transaction so rows are discarded on rollback.
 */
export async function createUser(
  tx: TestTx,
  options: { timeZone?: string } = {},
) {
  const [user] = await tx
    .insert(users)
    .values({ email: `${randomUUID()}@test.com` })
    .returning();

  if (options.timeZone !== undefined) {
    await tx
      .insert(userProfiles)
      .values({ userId: user!.id, timeZone: options.timeZone });
  }

  return user!;
}

export async function createProfile(
  tx: TestTx,
  userId: string,
  overrides: Partial<NewUserProfile> = {},
) {
  const [profile] = await tx
    .insert(userProfiles)
    .values({
      userId,
      weight: 80,
      height: 180,
      age: 30,
      gender: 'male',
      goal: 'maintain',
      activityLevel: 'medium',
      ...overrides,
    })
    .returning();
  return profile!;
}

export async function createCategory(tx: TestTx, name: string) {
  const [category] = await tx
    .insert(foodCategories)
    .values({ name })
    .returning();
  return category!;
}

export async function createCatalogFood(
  tx: TestTx,
  values: {
    name: string;
    caloriesPer100g?: number;
    proteinPer100g?: number;
    fatPer100g?: number;
    carbsPer100g?: number;
    source?: 'user' | 'system' | 'usda';
    createdBy?: string | null;
    barcode?: string | null;
    categoryId?: string | null;
  },
) {
  const [food] = await tx
    .insert(foods)
    .values({
      name: values.name,
      caloriesPer100g: values.caloriesPer100g ?? 100,
      proteinPer100g: values.proteinPer100g ?? 0,
      fatPer100g: values.fatPer100g ?? 0,
      carbsPer100g: values.carbsPer100g ?? 0,
      source: values.source ?? 'system',
      createdBy: values.createdBy ?? null,
      barcode: values.barcode ?? null,
      categoryId: values.categoryId ?? null,
    })
    .returning();
  return food!;
}
