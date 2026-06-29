import { Injectable, NotFoundException } from '@nestjs/common';
import { db } from '../db/db';
import { foodEntries } from '../db/schema/foodEntries';
import { foods } from '../db/schema/foods';
import { foodServings } from '../db/schema/foodServings';
import { userFoodStats } from '../db/schema/userFoodStats';
import { rawFoodImports } from '../db/schema/rawFoodImports';
import { eq, and, sql, desc, or, inArray } from 'drizzle-orm';
import { redis } from '../redis';
import { DailySummaryService } from '../daily-summary/daily-summary.service';
import { foodCategories } from '../db/schema/foodCategories';
import type { CreateFoodEntryDto, CreateFoodDto, CreateFoodCategoryDto, SearchFoodQueryDto } from './food.schema';

@Injectable()
export class FoodService {

  constructor(private readonly dailySummaryService: DailySummaryService) {}

  async create(userId: string, data: CreateFoodEntryDto) {
    let foodId = data.foodId;

    if (!foodId && data.grams && data.grams > 0) {
      const [existing] = await db
        .select()
        .from(foods)
        .where(eq(foods.name, data.name))
        .limit(1);

      if (existing) {
        foodId = existing.id;
      } else {
        const ratio = 100 / data.grams;
        const [created] = await db
          .insert(foods)
          .values({
            name: data.name,
            caloriesPer100g: Math.round(data.calories * ratio),
            proteinPer100g: Math.round((data.protein ?? 0) * ratio),
            fatPer100g: Math.round((data.fat ?? 0) * ratio),
            carbsPer100g: Math.round((data.carbs ?? 0) * ratio),
            source: 'user',
            createdBy: userId,
          })
          .returning();
        foodId = created!.id;
      }
    }

    const [entry] = await db
      .insert(foodEntries)
      .values({
        userId,
        foodId,
        grams: data.grams,
        name: data.name,
        calories: data.calories,
        protein: data.protein ?? 0,
        fat: data.fat ?? 0,
        carbs: data.carbs ?? 0,
      })
      .returning();

    if (foodId) {
      await db
        .insert(userFoodStats)
        .values({ userId, foodId, frequency: 1 })
        .onConflictDoUpdate({
          target: [userFoodStats.userId, userFoodStats.foodId],
          set: {
            frequency: sql`${userFoodStats.frequency} + 1`,
            lastUsedAt: sql`NOW()`,
          },
        });
    }

    await this.dailySummaryService.recalculate(userId);
    await this.invalidateAnalyticsCache(userId);

    return entry;
  }

  async getToday(userId: string) {
    return db
      .select()
      .from(foodEntries)
      .where(
        and(
          eq(foodEntries.userId, userId),
          sql`DATE(${foodEntries.createdAt}) = CURRENT_DATE`,
        ),
      );
  }

  async getByDate(userId: string, date: string) {
    return db
      .select()
      .from(foodEntries)
      .where(
        and(
          eq(foodEntries.userId, userId),
          sql`DATE(${foodEntries.createdAt}) = ${date}::date`,
        ),
      );
  }

  async delete(userId: string, id: string) {
    const [deleted] = await db
      .delete(foodEntries)
      .where(
        and(
          eq(foodEntries.id, id),
          eq(foodEntries.userId, userId),
        ),
      )
      .returning();

    if (!deleted) {
      throw new NotFoundException('Food entry not found');
    }

    await this.dailySummaryService.recalculate(userId);
    await this.invalidateAnalyticsCache(userId);

    return { message: 'Deleted' };
  }

  private async invalidateAnalyticsCache(userId: string) {
    await redis.del(`analytics:${userId}:week`);
    await redis.del(`analytics:${userId}:month`);
  }

  async getAll() {
    const allFoods = await db
      .select()
      .from(foods)
      .orderBy(foods.name);

    const categories = await db.select().from(foodCategories).orderBy(foodCategories.name);

    const grouped = categories.map((cat) => ({
      category: cat,
      foods: allFoods.filter((f) => f.categoryId === cat.id),
    }));

    const uncategorized = allFoods.filter((f) => !f.categoryId);
    if (uncategorized.length) {
      grouped.push({ category: { id: '', name: 'Uncategorized', icon: null, createdAt: new Date() }, foods: uncategorized });
    }

    return grouped;
  }

  // ── Food Categories ──────────────────────────────────────────

  async getCategories() {
    return db.select().from(foodCategories).orderBy(foodCategories.name);
  }

  async createCategory(data: CreateFoodCategoryDto) {
    const [category] = await db
      .insert(foodCategories)
      .values({ name: data.name, icon: data.icon })
      .returning();
    return category;
  }

  // ── Food Catalog ──────────────────────────────────────────────

  async search(userId: string, query: SearchFoodQueryDto) {
    const { q, limit } = query;
    const term = `%${q.toLowerCase()}%`;

    const local = await db
      .select()
      .from(foods)
      .where(
        or(
          sql`LOWER(${foods.name}) LIKE ${term}`,
          sql`${foods.barcode} LIKE ${term}`,
        ),
      )
      .limit(limit)
      .orderBy(foods.name);

    const localIds = local.map((f) => f.id);
    const localServings = localIds.length
      ? await db
          .select()
          .from(foodServings)
          .where(inArray(foodServings.foodId, localIds))
      : [];

    const localWithServings = local.map((food) => ({
      ...food,
      servings: localServings.filter((s) => s.foodId === food.id),
    }));

    if (local.length >= limit) return localWithServings;

    const remaining = limit - local.length;
    const localBarcodes = new Set(local.map((f) => f.barcode).filter(Boolean));

    try {
      const external = await this.searchOpenFoodFacts(q, remaining);
      const filtered = external.filter((f) => !localBarcodes.has(f.barcode));
      return [...localWithServings, ...filtered];
    } catch {
      return localWithServings;
    }
  }

  private async searchOpenFoodFacts(query: string, limit: number) {
    const url = new URL('https://world.openfoodfacts.org/cgi/search.pl');
    url.searchParams.set('search_terms', query);
    url.searchParams.set('json', '1');
    url.searchParams.set('page_size', String(limit));
    url.searchParams.set('lang', 'en');

    const res = await fetch(url.toString());
    if (!res.ok) return [];

    const rawBody = await res.json();
    const body = rawBody as {
      products?: Array<{
        product_name?: string;
        code?: string;
        image_url?: string;
        nutriments?: {
          'energy-kcal_100g'?: number;
          proteins_100g?: number;
          fat_100g?: number;
          carbohydrates_100g?: number;
        };
        categories?: string;
      }>;
    };

    try {
      await db.insert(rawFoodImports).values({
        source: 'openfoodfacts',
        rawData: rawBody,
        barcode: null,
        status: 'pending',
      });
    } catch {
      // не критично
    }

    if (!body.products?.length) return [];

    return body.products
      .filter((p) => p.product_name)
      .map((p) => ({
        id: '',
        name: p.product_name!.slice(0, 255),
        categoryId: null,
        caloriesPer100g: Math.round(p.nutriments?.['energy-kcal_100g'] ?? 0),
        proteinPer100g: Math.round(p.nutriments?.proteins_100g ?? 0),
        fatPer100g: Math.round(p.nutriments?.fat_100g ?? 0),
        carbsPer100g: Math.round(p.nutriments?.carbohydrates_100g ?? 0),
        barcode: p.code ?? null,
        imageUrl: p.image_url ?? null,
        source: 'openfoodfacts',
        createdBy: null,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      }));
  }

  async getPopular(userId: string) {
    const results = await db
      .select({
        food: foods,
        frequency: userFoodStats.frequency,
      })
      .from(userFoodStats)
      .where(eq(userFoodStats.userId, userId))
      .innerJoin(foods, eq(userFoodStats.foodId, foods.id))
      .orderBy(desc(userFoodStats.frequency))
      .limit(20);

    return results.map((r) => r.food);
  }

  async getByBarcode(barcode: string) {
    const [result] = await db
      .select()
      .from(foods)
      .where(eq(foods.barcode, barcode))
      .limit(1);

    return result ?? null;
  }

  async getById(id: string) {
    const [food] = await db.select().from(foods).where(eq(foods.id, id)).limit(1);
    if (!food) throw new NotFoundException('Food not found');

    const servings = await db
      .select()
      .from(foodServings)
      .where(eq(foodServings.foodId, id));

    return { ...food, servings };
  }

  async createFood(userId: string, data: CreateFoodDto) {
    const [food] = await db
      .insert(foods)
      .values({
        name: data.name,
        categoryId: data.categoryId,
        caloriesPer100g: Math.round(data.caloriesPer100g),
        proteinPer100g: Math.round(data.proteinPer100g ?? 0),
        fatPer100g: Math.round(data.fatPer100g ?? 0),
        carbsPer100g: Math.round(data.carbsPer100g ?? 0),
        barcode: data.barcode,
        imageUrl: data.imageUrl,
        source: 'user',
        createdBy: userId,
      })
      .returning();

    if (!food) throw new Error('Failed to create food');

    if (data.servings?.length) {
      await db.insert(foodServings).values(
        data.servings.map((s) => ({
          foodId: food.id,
          name: s.name,
          grams: s.grams,
        })),
      );
    }

    const servings = await db
      .select()
      .from(foodServings)
      .where(eq(foodServings.foodId, food.id));

    return { ...food, servings };
  }
}