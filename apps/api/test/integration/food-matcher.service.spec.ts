import { afterAll, beforeAll, describe, expect, it } from 'bun:test';
import { ConfigModule } from '@nestjs/config';

import { DbModule } from '../../src/db/db.module';
import { FoodModule } from '../../src/food/food.module';
import { FoodMatcherService } from '../../src/food/food-matcher.service';
import type { FoodAnalysisFoodItem } from '../../src/food/food.schema';
import { createTestModule } from '../utils/app';
import { createTestDb } from '../utils/db';
import type { TestDb, TestTx } from '../utils/db';
import { createCatalogFood, createCategory } from '../utils/seed';

let db: TestDb;
let tx: TestTx;
let rollback: () => Promise<void>;
let matcher: FoodMatcherService;

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
  matcher = moduleRef.get(FoodMatcherService);
});

afterAll(async () => {
  await rollback();
  await db.close();
});

const foodItem = (
  overrides: Partial<FoodAnalysisFoodItem>,
): FoodAnalysisFoodItem => ({
  kind: 'food',
  name: null,
  category: null,
  grams: null,
  calories: null,
  protein: null,
  fat: null,
  carbs: null,
  unit: null,
  imageUrl: null,
  confidence: null,
  foodId: null,
  source: null,
  aiCalories: null,
  catalogCalories: null,
  ...overrides,
});

describe('FoodMatcherService.matchItems', () => {
  it('marks items without a name as ai', async () => {
    const result = await matcher.matchItems([
      foodItem({ name: null, calories: 50 }),
    ]);
    expect(result[0]?.source).toBe('ai');
  });

  it('matches a catalog item and scales values to the grams', async () => {
    const category = await createCategory(tx, 'ZqMatcherCat');
    const food = await createCatalogFood(tx, {
      name: 'ZqChicken breast',
      caloriesPer100g: 165,
      proteinPer100g: 31,
      fatPer100g: 4,
      carbsPer100g: 0,
      source: 'system',
      categoryId: category.id,
    });

    const [result] = await matcher.matchItems([
      foodItem({
        name: 'ZqChicken breast',
        grams: 150,
        calories: 200,
        protein: 10,
        fat: 2,
        carbs: 1,
      }),
    ]);

    expect(result?.source).toBe('catalog');
    expect(result?.foodId).toBe(food.id);
    expect(result?.category).toBe('ZqMatcherCat');
    expect(result?.calories).toBe(247.5);
    expect(result?.protein).toBe(46.5);
    expect(result?.aiCalories).toBe(200);
    expect(result?.catalogCalories).toBe(247.5);
  });

  it('uses 100g when the item has no grams', async () => {
    await createCatalogFood(tx, {
      name: 'ZqRice',
      caloriesPer100g: 130,
      source: 'system',
    });

    const [result] = await matcher.matchItems([
      foodItem({ name: 'ZqRice', grams: null, calories: 999 }),
    ]);
    expect(result?.source).toBe('catalog');
    expect(result?.calories).toBe(130);
  });

  it('leaves an unmatched item as ai', async () => {
    const [result] = await matcher.matchItems([
      foodItem({ name: 'ZqDefinitelyMissing', grams: 100, calories: 42 }),
    ]);
    expect(result?.source).toBe('ai');
    expect(result?.foodId).toBeNull();
  });

  it('prefers a cooked product over a raw one', async () => {
    const cooked = await createCatalogFood(tx, {
      name: 'ZqBuckwheat cooked',
      caloriesPer100g: 110,
      source: 'system',
    });
    await createCatalogFood(tx, {
      name: 'ZqBuckwheat raw',
      caloriesPer100g: 340,
      source: 'system',
    });

    const [result] = await matcher.matchItems([
      foodItem({ name: 'ZqBuckwheat', grams: 100 }),
    ]);
    expect(result?.foodId).toBe(cooked.id);
  });

  it('rejects a candidate that scores below the threshold', async () => {
    await createCatalogFood(tx, {
      name: 'ZqPerlovka dry',
      caloriesPer100g: 350,
      source: 'system',
    });

    const [result] = await matcher.matchItems([
      foodItem({ name: 'perlovka', grams: 100 }),
    ]);
    expect(result?.source).toBe('ai');
  });
});
