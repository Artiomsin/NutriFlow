import { access, readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { and, eq, inArray, sql } from 'drizzle-orm';
import { createDb, createPool } from '../../src/db/db';
import { foodCategories } from '../../src/db/schema/foodCategories';
import { foods } from '../../src/db/schema/foods';
import { foodServings } from '../../src/db/schema/foodServings';

export type Serving = { name: string; grams: number };

export type Dish = {
  name: string;
  category: string;
  caloriesPer100g: number;
  proteinPer100g?: number;
  fatPer100g?: number;
  carbsPer100g?: number;
  servings?: Serving[];
};

export type Category = { name: string; icon?: string };

export type Catalog = {
  categories: Category[];
  foods: Dish[];
};

export type SeedSummary = {
  foods: number;
  servings: number;
};

export const CATALOG_FILE = fileURLToPath(
  new URL('../data/catalog.json', import.meta.url),
);

export const IMAGES_DIR = fileURLToPath(
  new URL('../data/images/', import.meta.url),
);

const IMAGE_EXTENSIONS = ['webp', 'jpg', 'jpeg', 'png'];

export const DEFAULT_SERVINGS: Record<string, Serving> = {
  Breakfast: { name: 'serving', grams: 250 },
  Soups: { name: 'bowl', grams: 350 },
  Salads: { name: 'plate', grams: 250 },
  Meat: { name: 'serving', grams: 200 },
  Seafood: { name: 'portion', grams: 180 },
  'Pasta & Grains': { name: 'plate', grams: 300 },
  'Vegetables & Sides': { name: 'side', grams: 150 },
  Desserts: { name: 'piece', grams: 120 },
  Drinks: { name: 'cup', grams: 240 },
  'Fast Food': { name: 'portion', grams: 250 },
  Snacks: { name: 'handful', grams: 40 },
  Bakery: { name: 'slice', grams: 60 },
};

export function slugify(name: string): string {
  return name
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

export function defaultServing(category: string): Serving {
  return DEFAULT_SERVINGS[category] ?? { name: 'serving', grams: 100 };
}

export function chunk<T>(items: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size)
    out.push(items.slice(i, i + size));
  return out;
}

export async function readCatalog(): Promise<Catalog> {
  return JSON.parse(await readFile(CATALOG_FILE, 'utf8')) as Catalog;
}

export async function findLocalImage(slug: string): Promise<string | null> {
  for (const ext of IMAGE_EXTENSIONS) {
    const candidate = `${IMAGES_DIR}${slug}.${ext}`;
    try {
      await access(candidate);
      return candidate;
    } catch {
      // try the next extension
    }
  }
  return null;
}

export function catalogImageUrl(slug: string): string {
  const mediaBaseUrl = (process.env.MEDIA_BASE_URL ?? '').replace(/\/+$/, '');
  if (mediaBaseUrl) return `${mediaBaseUrl}/catalog/${slug}.webp`;
  const publicUrl = (process.env.S3_PUBLIC_URL ?? '').replace(/\/+$/, '');
  if (!publicUrl) throw new Error('S3_PUBLIC_URL is not set');
  return `${publicUrl}/catalog/${slug}.webp`;
}

export function checkEnvironment(allowProd: boolean): string {
  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) throw new Error('DATABASE_URL is not set');
  const parsed = new URL(databaseUrl);
  const branch = process.env.NEON_BRANCH ?? '';
  const target = `${parsed.host}${parsed.pathname}`;
  const suspicious =
    /prod/i.test(branch) ||
    /prod/i.test(parsed.host) ||
    /prod/i.test(parsed.pathname);
  console.log(`Target DB: ${target} (branch: ${branch})`);
  if (suspicious && !allowProd) {
    throw new Error(
      'Target looks like production. Re-run with --allow-prod to proceed.',
    );
  }
  return databaseUrl;
}

export async function seedDatabase(
  databaseUrl: string,
  catalog: Catalog,
  dishes: Dish[],
  imageUrlFor: (dish: Dish) => string | null,
): Promise<SeedSummary> {
  const pool = createPool(databaseUrl);
  const db = createDb(pool);
  try {
    return await db.transaction(async (tx) => {
      if (catalog.categories.length > 0) {
        await tx
          .insert(foodCategories)
          .values(
            catalog.categories.map((c) => ({ name: c.name, icon: c.icon })),
          )
          .onConflictDoUpdate({
            target: foodCategories.name,
            set: { icon: sql`excluded.icon` },
          });
      }

      const categoryRows = await tx.select().from(foodCategories);
      const categoryIds = new Map(categoryRows.map((c) => [c.name, c.id]));

      const names = dishes.map((d) => d.name);
      if (names.length > 0) {
        await tx
          .delete(foods)
          .where(and(eq(foods.source, 'system'), inArray(foods.name, names)));
      }

      const foodIds = new Map<string, string>();
      for (const group of chunk(dishes, 100)) {
        const rows = await tx
          .insert(foods)
          .values(
            group.map((dish) => ({
              name: dish.name,
              categoryId: categoryIds.get(dish.category) ?? null,
              caloriesPer100g: Math.round(dish.caloriesPer100g),
              proteinPer100g: Math.round(dish.proteinPer100g ?? 0),
              fatPer100g: Math.round(dish.fatPer100g ?? 0),
              carbsPer100g: Math.round(dish.carbsPer100g ?? 0),
              imageUrl: imageUrlFor(dish),
              source: 'system' as const,
              createdBy: null,
            })),
          )
          .returning({ id: foods.id, name: foods.name });
        for (const row of rows) foodIds.set(row.name, row.id);
      }

      const servingRows: { foodId: string; name: string; grams: number }[] = [];
      for (const dish of dishes) {
        const foodId = foodIds.get(dish.name);
        if (!foodId) continue;
        for (const serving of dish.servings ?? [
          defaultServing(dish.category),
        ]) {
          servingRows.push({
            foodId,
            name: serving.name,
            grams: serving.grams,
          });
        }
      }
      for (const part of chunk(servingRows, 500)) {
        await tx.insert(foodServings).values(part);
      }

      return { foods: dishes.length, servings: servingRows.length };
    });
  } finally {
    await pool.end();
  }
}
