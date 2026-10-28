import { afterAll, beforeAll, describe, expect, it } from 'bun:test';
import { ConfigModule } from '@nestjs/config';
import { ConflictException, NotFoundException } from '@nestjs/common';
import { and, eq, sql } from 'drizzle-orm';
import { randomUUID } from 'node:crypto';

import { DbModule } from '../../src/db/db.module';
import { dailySummary } from '../../src/db/schema/dailySummary';
import { foodEntries } from '../../src/db/schema/foodEntries';
import { foods } from '../../src/db/schema/foods';
import { foodServings } from '../../src/db/schema/foodServings';
import { userFoodStats } from '../../src/db/schema/userFoodStats';
import { FoodModule } from '../../src/food/food.module';
import { FoodService } from '../../src/food/food.service';
import { createTestModule } from '../utils/app';
import { createTestDb } from '../utils/db';
import type { TestDb, TestTx } from '../utils/db';
import { createCatalogFood, createCategory, createUser } from '../utils/seed';

let db: TestDb;
let tx: TestTx;
let rollback: () => Promise<void>;
let service: FoodService;

beforeAll(async () => {
  db = createTestDb();
  const opened = await db.openTx();
  tx = opened.tx;
  rollback = opened.rollback;

  const moduleRef = await createTestModule(
    {
      imports: [ConfigModule.forRoot({ isGlobal: true }), DbModule, FoodModule],
    },
    tx,
  );
  service = moduleRef.get(FoodService);
});

afterAll(async () => {
  await rollback();
  await db.close();
});

async function summaryCalories(userId: string, date: string) {
  const [row] = await tx
    .select()
    .from(dailySummary)
    .where(
      and(
        eq(dailySummary.userId, userId),
        sql`${dailySummary.date} = ${date}::date`,
      ),
    );
  return row?.totalCalories ?? 0;
}

async function statsFor(userId: string, foodId: string) {
  const [row] = await tx
    .select()
    .from(userFoodStats)
    .where(
      and(eq(userFoodStats.userId, userId), eq(userFoodStats.foodId, foodId)),
    );
  return row;
}

describe('FoodService.create', () => {
  it('creates an entry from a visible food and updates summary and stats', async () => {
    const user = await createUser(tx);
    const food = await createCatalogFood(tx, {
      name: 'Oats',
      caloriesPer100g: 389,
      proteinPer100g: 17,
      fatPer100g: 7,
      carbsPer100g: 66,
      source: 'system',
    });

    const entry = await service.create(user.id, {
      name: 'Oats',
      foodId: food.id,
      grams: 100,
      calories: 389,
      protein: 17,
      fat: 7,
      carbs: 66,
      date: '2026-01-01',
    });

    expect(entry!.foodId).toBe(food.id);
    expect(await summaryCalories(user.id, '2026-01-01')).toBe(389);
    expect((await statsFor(user.id, food.id))?.frequency).toBe(1);
  });

  it("rejects another user's private food", async () => {
    const owner = await createUser(tx);
    const intruder = await createUser(tx);
    const secret = await createCatalogFood(tx, {
      name: 'Secret',
      source: 'user',
      createdBy: owner.id,
    });

    expect(
      service.create(intruder.id, {
        name: 'Secret',
        foodId: secret.id,
        calories: 10,
        date: '2026-01-02',
      }),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('creates a user food and computes per-100g values from the portion', async () => {
    const user = await createUser(tx);
    const entry = await service.create(user.id, {
      name: 'Apple',
      grams: 200,
      calories: 104,
      protein: 0,
      fat: 0,
      carbs: 28,
      date: '2026-01-03',
    });

    const [food] = await tx
      .select()
      .from(foods)
      .where(and(eq(foods.name, 'Apple'), eq(foods.createdBy, user.id)));

    expect(food).toBeDefined();
    expect(entry!.foodId).toBe(food!.id);
    expect(food!.caloriesPer100g).toBe(52);
    expect(food!.carbsPer100g).toBe(14);
  });

  it('creates a serving when servingGrams is provided', async () => {
    const user = await createUser(tx);
    const entry = await service.create(user.id, {
      name: 'Yogurt',
      grams: 200,
      calories: 120,
      servingGrams: 40,
      date: '2026-01-04',
    });

    const servings = await tx
      .select()
      .from(foodServings)
      .where(eq(foodServings.foodId, entry!.foodId!));
    expect(servings).toHaveLength(1);
    expect(servings[0]?.name).toBe('serving (40g)');
  });

  it('creates and links a category from categoryName', async () => {
    const user = await createUser(tx);
    const entry = await service.create(user.id, {
      name: 'Chicken',
      grams: 150,
      calories: 250,
      categoryName: 'Meat',
      date: '2026-01-05',
    });

    const [food] = await tx
      .select()
      .from(foods)
      .where(eq(foods.id, entry!.foodId!));
    expect(food?.categoryId).not.toBeNull();
  });

  it('reuses an existing visible food by name', async () => {
    const user = await createUser(tx);
    const existing = await createCatalogFood(tx, {
      name: 'Milk',
      source: 'system',
    });

    const entry = await service.create(user.id, {
      name: 'Milk',
      grams: 100,
      calories: 60,
      date: '2026-01-06',
    });

    expect(entry!.foodId).toBe(existing.id);
    const rows = await tx.select().from(foods).where(eq(foods.name, 'Milk'));
    expect(rows).toHaveLength(1);
  });

  it("stores an image on the user's own product", async () => {
    const user = await createUser(tx);
    const own = await createCatalogFood(tx, {
      name: 'MyDish',
      source: 'user',
      createdBy: user.id,
    });

    await service.create(user.id, {
      name: 'MyDish',
      foodId: own.id,
      calories: 100,
      imageUrl: 'https://cdn/dish.webp',
      date: '2026-01-07',
    });

    const [food] = await tx.select().from(foods).where(eq(foods.id, own.id));
    expect(food?.imageUrl).toBe('https://cdn/dish.webp');
  });

  it('does not store an image on a shared catalog product', async () => {
    const user = await createUser(tx);
    const shared = await createCatalogFood(tx, {
      name: 'Shared',
      source: 'system',
    });

    await service.create(user.id, {
      name: 'Shared',
      foodId: shared.id,
      calories: 100,
      imageUrl: 'https://cdn/x.webp',
      date: '2026-01-08',
    });

    const [food] = await tx.select().from(foods).where(eq(foods.id, shared.id));
    expect(food?.imageUrl).toBeNull();
  });
});

describe('FoodService reads', () => {
  it('getToday returns entries with the joined category name', async () => {
    const user = await createUser(tx);
    const category = await createCategory(tx, 'Fruit');
    const food = await createCatalogFood(tx, {
      name: 'Pear',
      source: 'system',
      categoryId: category.id,
    });
    await service.create(user.id, {
      name: 'Pear',
      foodId: food.id,
      calories: 57,
      date: '2026-01-09',
    });

    const rows = await service.getToday(user.id, '2026-01-09');
    expect(rows).toHaveLength(1);
    expect(rows[0]?.categoryName).toBe('Fruit');
  });

  it('getByDate returns the raw entries', async () => {
    const user = await createUser(tx);
    await service.create(user.id, {
      name: 'Rice',
      calories: 200,
      date: '2026-01-10',
    });

    const rows = await service.getByDate(user.id, '2026-01-10');
    expect(rows).toHaveLength(1);
    expect(rows[0]?.name).toBe('Rice');
  });
});

describe('FoodService.delete', () => {
  it('deletes the entry and decrements the summary', async () => {
    const user = await createUser(tx);
    const entry = await service.create(user.id, {
      name: 'Toast',
      calories: 150,
      date: '2026-02-01',
    });

    const result = await service.delete(user.id, entry!.id);
    expect(result).toEqual({ message: 'Deleted' });
    expect(await summaryCalories(user.id, '2026-02-01')).toBe(0);
  });

  it('throws for a missing entry', async () => {
    const user = await createUser(tx);
    expect(service.delete(user.id, randomUUID())).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it("throws for another user's entry", async () => {
    const owner = await createUser(tx);
    const intruder = await createUser(tx);
    const entry = await service.create(owner.id, {
      name: 'Soup',
      calories: 90,
      date: '2026-02-02',
    });

    expect(service.delete(intruder.id, entry!.id)).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });
});

describe('FoodService.update', () => {
  it('scales a non-catalog entry when grams change', async () => {
    const user = await createUser(tx);
    const [entry] = await tx
      .insert(foodEntries)
      .values({
        userId: user.id,
        name: 'Manual',
        foodId: null,
        grams: 100,
        calories: 160,
        protein: 2,
        fat: 15,
        carbs: 9,
        entryDate: '2026-09-01',
      })
      .returning();

    const updated = await service.update(user.id, entry!.id, { grams: 200 });
    expect(updated!.calories).toBe(320);
    expect(updated!.protein).toBe(4);
    expect(updated!.fat).toBe(30);
    expect(updated!.carbs).toBe(18);
  });

  it('forks a shared catalog product when its name changes', async () => {
    const user = await createUser(tx);
    const shared = await createCatalogFood(tx, {
      name: 'Milk',
      caloriesPer100g: 60,
      proteinPer100g: 3,
      fatPer100g: 3,
      carbsPer100g: 5,
      source: 'system',
    });
    const entry = await service.create(user.id, {
      name: 'Milk',
      foodId: shared.id,
      grams: 200,
      calories: 120,
      protein: 6,
      fat: 6,
      carbs: 10,
      date: '2026-10-01',
    });

    const updated = await service.update(user.id, entry!.id, {
      name: 'Milk 3%',
      grams: 200,
    });

    const [fork] = await tx
      .select()
      .from(foods)
      .where(and(eq(foods.source, 'user'), eq(foods.createdBy, user.id)));
    expect(fork).toBeDefined();
    expect(fork!.forkedFromId).toBe(shared.id);
    expect(fork!.name).toBe('Milk 3%');
    expect(fork!.caloriesPer100g).toBe(60);
    expect(updated!.foodId).toBe(fork!.id);
  });

  it('recomputes nutrients from the catalog when foodId changes', async () => {
    const user = await createUser(tx);
    const a = await createCatalogFood(tx, {
      name: 'A',
      caloriesPer100g: 100,
      source: 'system',
    });
    const b = await createCatalogFood(tx, {
      name: 'B',
      caloriesPer100g: 250,
      source: 'system',
    });
    const entry = await service.create(user.id, {
      name: 'A',
      foodId: a.id,
      grams: 100,
      calories: 100,
      date: '2026-10-02',
    });

    const updated = await service.update(user.id, entry!.id, { foodId: b.id });
    expect(updated!.foodId).toBe(b.id);
    expect(updated!.calories).toBe(250);
  });

  it('moves the entry to another date and shifts the summary', async () => {
    const user = await createUser(tx);
    const entry = await service.create(user.id, {
      name: 'Dinner',
      calories: 100,
      date: '2026-10-03',
    });

    await service.update(user.id, entry!.id, { date: '2026-10-04' });

    expect(await summaryCalories(user.id, '2026-10-03')).toBe(0);
    expect(await summaryCalories(user.id, '2026-10-04')).toBe(100);
  });

  it('sets and clears the category on a user-owned food', async () => {
    const user = await createUser(tx);
    const own = await createCatalogFood(tx, {
      name: 'Own',
      source: 'user',
      createdBy: user.id,
    });
    const entry = await service.create(user.id, {
      name: 'Own',
      foodId: own.id,
      calories: 10,
      date: '2026-10-05',
    });
    // Avoid colliding with the system catalog category seeded in the test DB.
    const category = await createCategory(tx, 'ZqSnacks');

    await service.update(user.id, entry!.id, { categoryName: 'ZqSnacks' });
    let [food] = await tx.select().from(foods).where(eq(foods.id, own.id));
    expect(food?.categoryId).toBe(category.id);

    await service.update(user.id, entry!.id, { categoryName: null });
    [food] = await tx.select().from(foods).where(eq(foods.id, own.id));
    expect(food?.categoryId).toBeNull();
  });

  it('keeps nutrients when a product-less entry is renamed and derives per-100g from its snapshot', async () => {
    const user = await createUser(tx);
    const [entry] = await tx
      .insert(foodEntries)
      .values({
        userId: user.id,
        foodId: null,
        name: 'Manual',
        grams: 150,
        unit: 'g',
        calories: 300,
        protein: 15,
        fat: 10,
        carbs: 30,
        entryDate: '2026-10-06',
      })
      .returning();

    const updated = await service.update(user.id, entry!.id, {
      name: 'Manual Renamed',
    });

    expect(updated!.name).toBe('Manual Renamed');
    expect(updated!.calories).toBe(300);
    expect(updated!.protein).toBe(15);
    expect(updated!.fat).toBe(10);
    expect(updated!.carbs).toBe(30);
    expect(updated!.foodId).not.toBeNull();

    const [product] = await tx
      .select()
      .from(foods)
      .where(eq(foods.id, updated!.foodId!));
    expect(product!.caloriesPer100g).toBe(200);
    expect(product!.proteinPer100g).toBe(10);
    expect(product!.fatPer100g).toBe(6.7);
    expect(product!.carbsPer100g).toBe(20);
  });

  it('throws for a missing entry', async () => {
    const user = await createUser(tx);
    expect(
      service.update(user.id, randomUUID(), { grams: 10 }),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});

describe('FoodService servings', () => {
  async function addCatalogServing(
    foodId: string,
    name: string,
    grams: number,
  ) {
    const [row] = await tx
      .insert(foodServings)
      .values({ foodId, name, grams, source: 'system', createdBy: null })
      .returning();
    return row!;
  }

  it('adds a personal portion to a catalog product', async () => {
    const user = await createUser(tx);
    const food = await createCatalogFood(tx, {
      name: 'Banana',
      caloriesPer100g: 89,
      source: 'system',
    });

    const serving = await service.addServing(user.id, food.id, {
      name: '1 banana',
      grams: 120,
    });

    expect(serving.source).toBe('user');
    expect(serving.createdBy).toBe(user.id);
    expect(serving.foodId).toBe(food.id);
  });

  it('rejects a duplicate portion name for the same owner', async () => {
    const user = await createUser(tx);
    const food = await createCatalogFood(tx, {
      name: 'Oats',
      source: 'system',
    });

    await service.addServing(user.id, food.id, { name: 'bowl', grams: 40 });

    await expect(
      service.addServing(user.id, food.id, { name: 'bowl', grams: 60 }),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('returns catalog and own portions but hides foreign ones', async () => {
    const user = await createUser(tx);
    const other = await createUser(tx);
    const food = await createCatalogFood(tx, {
      name: 'Milk',
      caloriesPer100g: 60,
      source: 'system',
    });

    await addCatalogServing(food.id, 'glass', 250);
    await service.addServing(user.id, food.id, {
      name: 'my glass',
      grams: 300,
    });
    await service.addServing(other.id, food.id, {
      name: 'foreign',
      grams: 100,
    });

    const result = await service.getById(food.id, user.id);

    expect(result.servings.map((s) => s.name).sort()).toEqual([
      'glass',
      'my glass',
    ]);
  });

  it('updates an own portion and reports a catalog one as missing', async () => {
    const user = await createUser(tx);
    const food = await createCatalogFood(tx, {
      name: 'Cottage',
      source: 'system',
    });
    const catalog = await addCatalogServing(food.id, 'pack', 200);
    const mine = await service.addServing(user.id, food.id, {
      name: 'half pack',
      grams: 100,
    });

    const updated = await service.updateServing(user.id, food.id, mine.id, {
      grams: 150,
    });
    expect(updated.grams).toBe(150);

    await expect(
      service.updateServing(user.id, food.id, catalog.id, { grams: 999 }),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it("does not update another user's portion", async () => {
    const user = await createUser(tx);
    const other = await createUser(tx);
    const food = await createCatalogFood(tx, {
      name: 'Bread',
      source: 'system',
    });
    const foreign = await service.addServing(other.id, food.id, {
      name: 'slice',
      grams: 30,
    });

    await expect(
      service.updateServing(user.id, food.id, foreign.id, { grams: 50 }),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('deletes an own portion and keeps the catalog one', async () => {
    const user = await createUser(tx);
    const food = await createCatalogFood(tx, {
      name: 'Soup',
      source: 'system',
    });
    const catalog = await addCatalogServing(food.id, 'bowl', 300);
    const mine = await service.addServing(user.id, food.id, {
      name: 'my bowl',
      grams: 250,
    });

    await expect(
      service.removeServing(user.id, food.id, mine.id),
    ).resolves.toEqual({ id: mine.id });

    const result = await service.getById(food.id, user.id);
    expect(result.servings.map((s) => s.id)).toEqual([catalog.id]);

    await expect(
      service.removeServing(user.id, food.id, catalog.id),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('marks a portion created from a food entry as personal', async () => {
    const user = await createUser(tx);
    const entry = await service.create(user.id, {
      name: 'Kefir',
      grams: 250,
      calories: 120,
      servingGrams: 50,
      date: '2026-01-05',
    });

    const [serving] = await tx
      .select()
      .from(foodServings)
      .where(eq(foodServings.foodId, entry!.foodId!));

    expect(serving?.source).toBe('user');
    expect(serving?.createdBy).toBe(user.id);
  });
});
