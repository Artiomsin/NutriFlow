import { randomUUID } from 'node:crypto';

import { users } from '../../src/db/schema/users';
import { userProfiles } from '../../src/db/schema/userProfiles';
import { foods } from '../../src/db/schema/foods';
import { foodCategories } from '../../src/db/schema/foodCategories';
import type { TestTx } from './db';

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
