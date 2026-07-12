import { Injectable, NotFoundException } from '@nestjs/common';
import { db } from '../db/db';
import { foodEntries } from '../db/schema/foodEntries';
import { foods } from '../db/schema/foods';
import { foodServings } from '../db/schema/foodServings';
import { userFoodStats } from '../db/schema/userFoodStats';
import { eq, and, sql, desc, or, inArray } from 'drizzle-orm';
import { cacheGet, cacheSet, invalidateAnalyticsCache } from '../redis';
import { DailySummaryService } from '../daily-summary/daily-summary.service';
import { foodCategories } from '../db/schema/foodCategories';
import { env } from '../config/env';
import type { CreateFoodEntryDto, CreateFoodDto, CreateFoodCategoryDto, SearchFoodQueryDto } from './food.schema';

interface OFProduct {
  id: string;
  name: string;
  brand: string | null;
  categoryName: string | null;
  categoryId: string | null;
  caloriesPer100g: number;
  proteinPer100g: number;
  fatPer100g: number;
  carbsPer100g: number;
  barcode: string | null;
  imageUrl: string | null;
  source: string;
  createdBy: string | null;
  createdAt: string;
  updatedAt: string;
  servings?: Array<{ id: string; foodId: string; name: string; grams: number; createdAt: string | null }>;
  score?: number;
}

@Injectable()
export class FoodService {

  private normalizeCache = new Map<string, string>();
  private readonly NORMALIZE_CACHE_MAX = 500;

  constructor(private readonly dailySummaryService: DailySummaryService) {}

  async create(userId: string, data: CreateFoodEntryDto) {
    const result = await db.transaction(async (tx) => {
      let foodId = data.foodId;

      if (!foodId && data.name) {
        const [existing] = await tx
          .select()
          .from(foods)
          .where(eq(foods.name, data.name))
          .limit(1);

        if (existing) {
          foodId = existing.id;
        } else {
          let categoryId: string | null = null;

          if (data.categoryName) {
            const [cat] = await tx
              .insert(foodCategories)
              .values({ name: data.categoryName })
              .onConflictDoNothing({ target: foodCategories.name })
              .returning();

            if (cat) {
              categoryId = cat.id;
            } else {
              const [found] = await tx
                .select()
                .from(foodCategories)
                .where(eq(foodCategories.name, data.categoryName))
                .limit(1);
              categoryId = found?.id ?? null;
            }
          }

          const ratio = data.grams && data.grams > 0 ? 100 / data.grams : 1;
          const source = data.brand ? 'usda' : 'user';

          const [created] = await tx
            .insert(foods)
            .values({
              name: data.name,
              brand: data.brand,
              categoryId,
              barcode: data.barcode,
              imageUrl: data.imageUrl,
              caloriesPer100g: Math.round(data.calories * ratio),
              proteinPer100g: Math.round((data.protein ?? 0) * ratio),
              fatPer100g: Math.round((data.fat ?? 0) * ratio),
              carbsPer100g: Math.round((data.carbs ?? 0) * ratio),
              source,
              createdBy: userId,
            })
            .returning();
          foodId = created!.id;

          if (data.servingGrams && data.servingGrams > 0) {
            await tx.insert(foodServings).values({
              foodId,
              name: `serving (${data.servingGrams}g)`,
              grams: data.servingGrams,
            });
          }
        }
      }

      const [entry] = await tx
        .insert(foodEntries)
        .values({
          userId,
          foodId,
          grams: data.grams,
          unit: data.unit ?? 'g',
          name: data.name,
          calories: data.calories,
          protein: data.protein ?? 0,
          fat: data.fat ?? 0,
          carbs: data.carbs ?? 0,
          imageUrl: data.imageUrl,
          entryDate: data.date,
        })
        .returning();

      if (foodId && data.imageUrl) {
        await tx
          .update(foods)
          .set({ imageUrl: data.imageUrl })
          .where(eq(foods.id, foodId));
      }

      if (foodId) {
        await tx
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

      return entry;
    });

    await this.dailySummaryService.adjust(userId, {
      calories: data.calories,
      protein: data.protein ?? 0,
      fat: data.fat ?? 0,
      carbs: data.carbs ?? 0,
      date: data.date,
    });
    await invalidateAnalyticsCache(userId);

    return result;
  }

  async getToday(userId: string, dateStr?: string) {
    const dateClause = dateStr ? sql`${dateStr}::date` : sql`CURRENT_DATE`;
    return db
      .select({
        id: foodEntries.id,
        userId: foodEntries.userId,
        foodId: foodEntries.foodId,
        name: foodEntries.name,
        grams: foodEntries.grams,
        unit: foodEntries.unit,
        calories: foodEntries.calories,
        protein: foodEntries.protein,
        fat: foodEntries.fat,
        carbs: foodEntries.carbs,
        createdAt: foodEntries.createdAt,
        updatedAt: foodEntries.updatedAt,
        categoryName: foodCategories.name,
        imageUrl: sql`COALESCE(${foodEntries.imageUrl}, ${foods.imageUrl})`,
      })
      .from(foodEntries)
      .leftJoin(foods, eq(foodEntries.foodId, foods.id))
      .leftJoin(foodCategories, eq(foods.categoryId, foodCategories.id))
      .where(
        and(
          eq(foodEntries.userId, userId),
          eq(foodEntries.entryDate, dateClause),
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
          eq(foodEntries.entryDate, sql`${date}::date`),
        ),
      );
  }

  async delete(userId: string, id: string, date?: string) {
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

    const deletedDate = date ?? deleted.entryDate ?? (deleted.createdAt instanceof Date
      ? deleted.createdAt.toISOString().split('T')[0]
      : undefined);
    await this.dailySummaryService.adjust(userId, {
      calories: -deleted.calories,
      protein: -(deleted.protein ?? 0),
      fat: -(deleted.fat ?? 0),
      carbs: -(deleted.carbs ?? 0),
      date: deletedDate,
    });
    await invalidateAnalyticsCache(userId);

    return { message: 'Deleted' };
  }

  async getAll(limit = 50, offset = 0) {
    const rows = await db
      .select({
        food: foods,
        categoryId: foodCategories.id,
        categoryName: foodCategories.name,
        categoryIcon: foodCategories.icon,
      })
      .from(foods)
      .leftJoin(foodCategories, eq(foods.categoryId, foodCategories.id))
      .orderBy(foods.name)
      .limit(limit)
      .offset(offset);

    const catMap = new Map<string, {
      id: string; name: string; icon: string | null; foods: typeof foods.$inferSelect[];
    }>();

    for (const row of rows) {
      const key = row.categoryId ?? '';
      let group = catMap.get(key);
      if (!group) {
        group = {
          id: row.categoryId ?? '',
          name: row.categoryName ?? 'Uncategorized',
          icon: row.categoryIcon ?? null,
          foods: [],
        };
        catMap.set(key, group);
      }
      group.foods.push({ ...row.food });
    }

    return Array.from(catMap.values());
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

  async search(query: SearchFoodQueryDto) {
    const { q, limit } = query;

    // Extract weight from query with unit conversion
    const weightMatch = q.match(/(\d+([.,]\d+)?)\s*(g|kg|ml|l|oz|lb)\b/i);
    let suggestedGrams: number | null = null;
    let suggestedUnit: string | null = null;

    if (weightMatch?.[1]) {
      const value = parseFloat(weightMatch[1].replace(',', '.'));
      const rawUnit = (weightMatch[3] ?? '').toLowerCase();

      const unitMap: Record<string, { mul: number; display: string }> = {
        'g': { mul: 1, display: 'g' },
        'kg': { mul: 1000, display: 'g' },
        'ml': { mul: 1, display: 'ml' },
        'l': { mul: 1000, display: 'ml' },
        'oz': { mul: 28.35, display: 'g' },
        'lb': { mul: 453.6, display: 'g' },
      };

      const conversion = unitMap[rawUnit];
      if (conversion) {
        suggestedGrams = Math.round(value * conversion.mul);
        suggestedUnit = conversion.display;
      }
    }

    const normalizedQ = q.toLowerCase().trim();

    // 1. Cache check (Redis)
    const cacheKey = `search:${normalizedQ}`;
    const cached = await cacheGet<OFProduct[]>(cacheKey);
    if (cached) return { foods: cached, suggestedGrams, suggestedUnit };

    // 2. Local DB search (full-text + LIKE fallback)
    const term = `%${normalizedQ}%`;
    const localRows = await db
      .select({
        food: foods,
        categoryName: foodCategories.name,
      })
      .from(foods)
      .leftJoin(foodCategories, eq(foods.categoryId, foodCategories.id))
      .where(
        or(
          sql`to_tsvector('simple', ${foods.name}) @@ plainto_tsquery('simple', ${normalizedQ})`,
          sql`${foods.name} ILIKE ${term}`,
          sql`${foods.barcode} LIKE ${term}`,
        ),
      )
      .orderBy(foods.name)
      .limit(limit);

    const localIds = localRows.map((r) => r.food.id);

    const localServings = localIds.length
      ? await db
          .select()
          .from(foodServings)
          .where(inArray(foodServings.foodId, localIds))
      : [];

    const local: OFProduct[] = localRows.map((row) => {
      const f = row.food;
      return {
        id: f.id,
        name: f.name,
        brand: f.brand,
        categoryName: row.categoryName ?? null,
        categoryId: f.categoryId,
        caloriesPer100g: f.caloriesPer100g,
        proteinPer100g: f.proteinPer100g ?? 0,
        fatPer100g: f.fatPer100g ?? 0,
        carbsPer100g: f.carbsPer100g ?? 0,
        barcode: f.barcode,
        imageUrl: f.imageUrl,
        source: f.source,
        createdBy: f.createdBy,
        createdAt: f.createdAt instanceof Date ? f.createdAt.toISOString() : String(f.createdAt),
        updatedAt: f.updatedAt instanceof Date ? f.updatedAt.toISOString() : String(f.updatedAt),
        servings: localServings
          .filter((s) => s.foodId === f.id)
          .map((s) => ({
            id: s.id,
            foodId: s.foodId,
            name: s.name,
            grams: s.grams,
            createdAt: s.createdAt instanceof Date ? s.createdAt.toISOString() : null,
          })),
      };
    });

    if (local.length >= limit) {
      await cacheSet(cacheKey, local);
      return { foods: local, suggestedGrams, suggestedUnit };
    }

    // 3. Parallel external search (USDA SR Legacy + USDA Branded)
    // — очищаем query от весов и мусора перед отправкой в API
    const cleanQuery = normalizedQ
      .replace(/\b\d+([.,]\d+)?\s?(г|g|kg|ml|l|oz|lb)\b/gi, '')
      .replace(/[^\p{L}\p{N}\s]/gu, ' ')
      .replace(/\s+/g, ' ')
      .trim() || normalizedQ;

    const [srLegacyRes, brandedRes] = await Promise.allSettled([
      this.searchUSDA(cleanQuery, 25, 'SR Legacy'),
      this.searchUSDA(cleanQuery, 25, 'Branded'),
    ]);

    const srItems: OFProduct[] = srLegacyRes.status === 'fulfilled' ? srLegacyRes.value : [];
    const brandedItems: OFProduct[] = brandedRes.status === 'fulfilled' ? brandedRes.value : [];

    // — SR Legacy идёт перед Branded, чтобы при дедупе выигрывал generic продукт
    const allUsda = [...srItems, ...brandedItems];

    // 4. Dedup across ALL items (local first, then external)
    const allItems = [...local, ...allUsda];
    const deduped = this.deduplicate(allItems);

    // 5. Rank
    const ranked = this.rank(deduped, normalizedQ);

    // 6. Save cache (only foods, not suggestedGrams)
    const results = ranked.slice(0, limit);
    await cacheSet(cacheKey, results);

    return { foods: results, suggestedGrams, suggestedUnit };
  }

  private normalize(name: string): string {
    if (this.normalizeCache.has(name)) return this.normalizeCache.get(name)!;

    const result = name
      .toLowerCase()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .replace(/\([^)]*\)/g, '')
      .replace(/\[[^\]]*]/g, '')
      .replace(/\b\d+([.,]\d+)?\s?(g|kg|ml|l|oz|lb)\b/g, '')
      .replace(
        /\b(organic|bio|fresh|natural|premium|classic|original|traditional|pure|real|whole|light|extra|aged|mild|mature|smoked)\b/g,
        '',
      )
      .replace(/[^a-z0-9\s]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();

    this.normalizeCache.set(name, result);
    if (this.normalizeCache.size > this.NORMALIZE_CACHE_MAX) {
      const firstKey = this.normalizeCache.keys().next().value;
      if (firstKey) this.normalizeCache.delete(firstKey);
    }
    return result;
  }

  private normalizeKey(name: string): string {
    return this.normalize(name)
      .replace(
        /\b(cheese|food|product|pack|piece|slices|slice|block)\b/g,
        '',
      )
      .replace(/\s+/g, ' ')
      .trim();
  }

  private tokenize(name: string): Set<string> {
    return new Set(
      this.normalize(name)
        .split(/\s+/)
        .filter((t) => t.length > 2),
    );
  }

  private usdaQueue: Promise<void> = Promise.resolve();

  private async rateLimitedFetch(url: string): Promise<Response> {
    const prev = this.usdaQueue;
    let done: () => void;
    this.usdaQueue = new Promise((r) => { done = r; });
    await prev;
    await new Promise((r) => setTimeout(r, 250));
    try {
      return await fetch(url);
    } finally {
      done!();
    }
  }

  private async searchUSDA(query: string, pageSize: number, dataType: string): Promise<OFProduct[]> {
    const url = new URL('https://api.nal.usda.gov/fdc/v1/foods/search');
    url.searchParams.set('api_key', env.USDA_API_KEY);
    url.searchParams.set('query', query);
    url.searchParams.set('pageSize', String(pageSize));
    url.searchParams.set('dataType', dataType);

    const res = await this.rateLimitedFetch(url.toString());
    if (!res.ok) {
      console.error(`[USDA] ${dataType} returned ${res.status}: ${res.statusText}`);
      return [];
    }

    const body = await res.json() as {
      foods?: Array<{
        fdcId: number;
        description: string;
        foodNutrients?: Array<{
          nutrientId: number;
          value?: number;
        }>;
        gtinUpc?: string;
        brandName?: string;
        brandOwner?: string;
        foodCategory?: string;
      }>;
    };

    if (!body.foods?.length) return [];

    return body.foods
      .filter((f) => f.description)
      .map((f) => ({
        id: '',
        name: f.description.slice(0, 255),
        brand: f.brandName ?? f.brandOwner ?? null,
        categoryName: f.foodCategory ?? null,
        categoryId: null,
        caloriesPer100g: this.extractNutrient(f.foodNutrients, 1008),
        proteinPer100g: this.extractNutrient(f.foodNutrients, 1003),
        fatPer100g: this.extractNutrient(f.foodNutrients, 1004),
        carbsPer100g: this.extractNutrient(f.foodNutrients, 1005),
        barcode: f.gtinUpc ?? null,
        imageUrl: null,
        source: dataType === 'SR Legacy' ? 'usda_sr' : 'usda',
        createdBy: null,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      }));
  }

  private extractNutrient(
    nutrients: Array<{ nutrientId: number; value?: number }> | undefined,
    id: number,
  ): number {
    return Math.round(nutrients?.find((n) => n.nutrientId === id)?.value ?? 0);
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
    const [food] = await db
      .select()
      .from(foods)
      .where(eq(foods.barcode, barcode))
      .limit(1);

    if (!food) return null;

    const servings = await db
      .select()
      .from(foodServings)
      .where(eq(foodServings.foodId, food.id));

    return { ...food, servings };
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

  // ── Dedup (3 уровня) ─────────────────────────────────────────

  private deduplicate(items: OFProduct[]): OFProduct[] {
    const seenBarcodes = new Set<string>();
    const seenNames = new Set<string>();
    const seenTokens: Set<string>[] = [];
    const result: OFProduct[] = [];

    for (const item of items) {
      if (item.barcode) {
        if (seenBarcodes.has(item.barcode)) continue;
        seenBarcodes.add(item.barcode);
      }

      const normalized = this.normalizeKey(item.name);
      if (!normalized.length) continue;
      if (seenNames.has(normalized)) continue;

      const tokens = this.tokenize(item.name);
      if (tokens.size) {
        const isDup = seenTokens.some((seen) => {
          if (!seen.size) return false;
          const intersection = new Set([...seen].filter((t) => tokens.has(t)));
          const union = new Set([...seen, ...tokens]);
          return intersection.size / union.size >= 0.55;
        });
        if (isDup) continue;
      }

      seenNames.add(normalized);
      seenTokens.push(tokens);
      result.push(item);
    }

    return result;
  }

  // ── Ranking ────────────────────────────────────────────────

  private rank(items: OFProduct[], query: string): OFProduct[] {
    const qLower = query.toLowerCase();
    const qWords = qLower.split(/\s+/).filter((w) => w.length > 0);

    return items
      .map((item) => {
        const nameLower = item.name.toLowerCase();
        const nameWords = nameLower.split(/\s+/);
        let score = 0;

        if (item.source === 'local' || item.id) score += 10;
        else if (item.source === 'usda_sr') score += 8;
        else if (item.source === 'usda') score += 6;

        if (nameLower === qLower) score += 3;
        else if (nameLower.startsWith(qLower)) score += 2;
        else if (nameLower.includes(qLower)) score += 1;

        for (const qw of qWords) {
          if (nameWords.some((nw) => nw === qw || nw.startsWith(qw))) {
            score += 0.5;
          }
        }

        if (item.barcode) score += 1;
        if (item.brand) score += 0.25;
        if (item.imageUrl) score += 0.5;
        if (item.servings?.length) score += 0.5;

        return { ...item, score };
      })
      .sort((a, b) => (b.score ?? 0) - (a.score ?? 0));
  }
}