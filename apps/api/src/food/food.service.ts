import {
  ConflictException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import type { Db, Transaction } from '../db/db';
import { DB } from '../db/db.module';
import { foodEntries } from '../db/schema/foodEntries';
import { foods } from '../db/schema/foods';
import {
  foodServings,
  SERVING_SOURCE_SYSTEM,
  SERVING_SOURCE_USER,
} from '../db/schema/foodServings';
import type { FoodServing } from '../db/schema/foodServings';
import { userFoodStats } from '../db/schema/userFoodStats';
import {
  eq,
  and,
  sql,
  desc,
  or,
  ne,
  isNull,
  count,
  inArray,
  type SQL,
} from 'drizzle-orm';
import { DailySummaryService } from '../daily-summary/daily-summary.service';
import { foodCategories } from '../db/schema/foodCategories';
import { env } from '../config/env';
import type {
  CreateFoodEntryDto,
  UpdateFoodEntryDto,
  CreateFoodDto,
  CreateFoodCategoryDto,
  UpdateFoodCategoryDto,
  CreateFoodServingDto,
  UpdateFoodServingDto,
  SearchFoodQueryDto,
} from './food.schema';
import { currentUserDate } from '../common/time/user-date';
import { RedisService } from '../redis/redis.service';
import {
  clampNutrition,
  roundNutrition,
} from '../common/nutrition/precision';

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
  servings?: Array<{
    id: string;
    foodId: string;
    name: string;
    grams: number;
    createdAt: string | null;
  }>;
  score?: number;
  frequency?: number;
}

@Injectable()
export class FoodService {
  private normalizeCache = new Map<string, string>();
  private readonly NORMALIZE_CACHE_MAX = 500;
  private static readonly PRELOAD_PAGE_SIZE = 20;

  constructor(
    private readonly dailySummaryService: DailySummaryService,
    @Inject(DB) private readonly db: Db,
    private readonly redis: RedisService,
  ) {}

  private visibilityClause(userId: string) {
    return or(
      sql`${foods.source} IN ('usda', 'system')`,
      and(eq(foods.source, 'user'), eq(foods.createdBy, userId)),
    );
  }

  private async findVisibleFood(
    id: string,
    userId: string,
    executor: Db | Transaction = this.db,
  ) {
    const [food] = await executor
      .select()
      .from(foods)
      .where(and(eq(foods.id, id), this.visibilityClause(userId)))
      .limit(1);
    return food;
  }

  /**
   * Catalog portions ('system') are readable by everyone who may see the
   * food; personal portions ('user') belong to their creator alone.
   */
  private servingVisibilityClause(userId?: string) {
    if (!userId) return eq(foodServings.source, SERVING_SOURCE_SYSTEM);

    return or(
      eq(foodServings.source, SERVING_SOURCE_SYSTEM),
      and(
        eq(foodServings.source, SERVING_SOURCE_USER),
        eq(foodServings.createdBy, userId),
      ),
    );
  }

  /**
   * Categories a user may see: the shared catalog ones plus their own.
   * Ownership is expressed in SQL rather than checked after the fact, so a
   * missing row and a foreign row are indistinguishable to the caller.
   */
  private categoryVisibilityClause(userId: string): SQL {
    return or(
      isNull(foodCategories.createdBy),
      eq(foodCategories.createdBy, userId),
    )!;
  }

  /** Every write of a personal category goes through the owner scope. */
  private categoryOwnershipClause(userId: string, id: string): SQL {
    return and(
      eq(foodCategories.id, id),
      eq(foodCategories.createdBy, userId),
    )!;
  }

  /**
   * Maps a free-form category name onto a category the user may use.
   *
   * A system category wins when it exists, then the user's own one is reused,
   * and only otherwise is a personal category created. Runtime code never adds
   * rows to the shared catalog: that stays the job of the seed script.
   */
  private async resolveCategory(
    executor: Db | Transaction,
    userId: string,
    name: string | null | undefined,
  ): Promise<string | null> {
    const clean = name?.trim();
    if (!clean) return null;

    const [existing] = await executor
      .select({ id: foodCategories.id })
      .from(foodCategories)
      .where(
        and(
          eq(foodCategories.name, clean),
          this.categoryVisibilityClause(userId),
        ),
      )
      .orderBy(sql`${foodCategories.createdBy} IS NOT NULL`)
      .limit(1);

    if (existing) return existing.id;

    const [created] = await executor
      .insert(foodCategories)
      .values({ name: clean, createdBy: userId })
      .returning({ id: foodCategories.id });

    return created?.id ?? null;
  }

  /**
   * Guards a category id supplied by a client. A shared category and one of
   * the caller's own are both acceptable; anything else is reported as missing
   * so a foreign category cannot be probed or attached to a product.
   */
  private async assertVisibleCategory(
    executor: Db | Transaction,
    userId: string,
    categoryId: string,
  ): Promise<void> {
    const [visible] = await executor
      .select({ id: foodCategories.id })
      .from(foodCategories)
      .where(
        and(
          eq(foodCategories.id, categoryId),
          this.categoryVisibilityClause(userId),
        ),
      )
      .limit(1);

    if (!visible) throw new NotFoundException('Category not found');
  }

  private listServings(
    foodId: string,
    userId?: string,
    executor: Db | Transaction = this.db,
  ) {
    return executor
      .select()
      .from(foodServings)
      .where(
        and(
          eq(foodServings.foodId, foodId),
          this.servingVisibilityClause(userId),
        ),
      );
  }

  /** Every write of a personal portion goes through the owner scope. */
  private servingOwnershipClause(userId: string, foodId: string, id: string) {
    return and(
      eq(foodServings.id, id),
      eq(foodServings.foodId, foodId),
      eq(foodServings.source, SERVING_SOURCE_USER),
      eq(foodServings.createdBy, userId),
    );
  }

  async create(userId: string, data: CreateFoodEntryDto) {
    const entryDate = data.date ?? (await currentUserDate(userId, this.db));
    const result = await this.db.transaction(async (tx) => {
      let foodId = data.foodId;

      if (foodId && !(await this.findVisibleFood(foodId, userId, tx))) {
        throw new NotFoundException('Food not found');
      }

      if (!foodId && data.name) {
        const [existing] = await tx
          .select()
          .from(foods)
          .where(and(eq(foods.name, data.name), this.visibilityClause(userId)))
          .limit(1);

        if (existing) {
          foodId = existing.id;
        } else {
          // A category named by the client becomes a personal one: the shared
          // catalog only ever grows through the seed script.
          const categoryId = await this.resolveCategory(
            tx,
            userId,
            data.categoryName,
          );

          const ratio = data.grams && data.grams > 0 ? 100 / data.grams : 1;
          const source = 'user';

          const per100g = (value: number, max: number) =>
            clampNutrition(value * ratio, max);

          const [created] = await tx
            .insert(foods)
            .values({
              name: data.name,
              brand: data.brand,
              categoryId,
              barcode: data.barcode,
              imageUrl: data.imageUrl,
              caloriesPer100g: per100g(data.calories, 1000),
              proteinPer100g: per100g(data.protein ?? 0, 100),
              fatPer100g: per100g(data.fat ?? 0, 100),
              carbsPer100g: per100g(data.carbs ?? 0, 100),
              source,
              createdBy: userId,
            })
            .returning();
          foodId = created!.id;

          if (data.servingGrams && data.servingGrams > 0) {
            // The portion is created together with a private product, so it
            // belongs to the same user and stays editable afterwards.
            await tx.insert(foodServings).values({
              foodId,
              name: `serving (${data.servingGrams}g)`,
              grams: data.servingGrams,
              source: SERVING_SOURCE_USER,
              createdBy: userId,
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
          entryDate,
        })
        .returning();

      // The catalog must not change based on someone else's choice: an
      // image can only be saved onto the user's own product.
      if (foodId && data.imageUrl) {
        const [food] = await tx
          .select({ source: foods.source, createdBy: foods.createdBy })
          .from(foods)
          .where(eq(foods.id, foodId))
          .limit(1);

        if (food && food.source === 'user' && food.createdBy === userId) {
          await tx
            .update(foods)
            .set({ imageUrl: data.imageUrl })
            .where(eq(foods.id, foodId));
        }
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

      await this.dailySummaryService.adjust(
        userId,
        {
          calories: data.calories,
          protein: data.protein ?? 0,
          fat: data.fat ?? 0,
          carbs: data.carbs ?? 0,
          date: entryDate,
        },
        tx,
      );

      return entry;
    });

    return result;
  }

  async getToday(userId: string, dateStr?: string) {
    const date = dateStr ?? (await currentUserDate(userId, this.db));
    const dateClause = sql`${date}::date`;
    return this.db
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
        foodSource: foods.source,
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
    return this.db
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
    const result = await this.db.transaction(async (tx) => {
      const [deleted] = await tx
        .delete(foodEntries)
        .where(and(eq(foodEntries.id, id), eq(foodEntries.userId, userId)))
        .returning();

      if (!deleted) {
        throw new NotFoundException('Food entry not found');
      }

      const deletedDate =
        deleted.entryDate ??
        date ??
        (deleted.createdAt instanceof Date
          ? deleted.createdAt.toISOString().split('T')[0]
          : undefined);
      await this.dailySummaryService.adjust(
        userId,
        {
          calories: -deleted.calories,
          protein: -(deleted.protein ?? 0),
          fat: -(deleted.fat ?? 0),
          carbs: -(deleted.carbs ?? 0),
          date: deletedDate,
        },
        tx,
      );

      return { message: 'Deleted' };
    });
    return result;
  }

  async update(userId: string, id: string, data: UpdateFoodEntryDto) {
    const [existing] = await this.db
      .select()
      .from(foodEntries)
      .where(and(eq(foodEntries.id, id), eq(foodEntries.userId, userId)))
      .limit(1);

    if (!existing) {
      throw new NotFoundException('Food entry not found');
    }

    let newFoodId = existing.foodId;
    let newName = data.name ?? existing.name;
    let newGrams = data.grams ?? existing.grams;
    let newCalories = existing.calories;
    let newProtein = existing.protein ?? 0;
    let newFat = existing.fat ?? 0;
    let newCarbs = existing.carbs ?? 0;
    let newEntryDate: string | SQL<unknown> =
      data.date ?? existing.entryDate ?? sql`CURRENT_DATE`;
    let newImageUrl = data.imageUrl ?? existing.imageUrl;
    let newUnit = data.unit ?? existing.unit;
    // Set when a manual entry (no product) is renamed: the product is created as
    // a copy of the entry snapshot, so its per-100g values must come from the
    // entry (never zero) and the entry nutrients must not be recalculated from it.
    let createdFromSnapshot = false;

    // A manual/AI entry without a catalog product has nutrients defined
    // for a specific portion. When grams change we scale them proportionally.
    if (
      !existing.foodId &&
      data.grams !== undefined &&
      data.calories === undefined &&
      existing.grams &&
      existing.grams > 0
    ) {
      const ratio = data.grams / existing.grams;
      newCalories = roundNutrition(existing.calories * ratio);
      newProtein = roundNutrition((existing.protein ?? 0) * ratio);
      newFat = roundNutrition((existing.fat ?? 0) * ratio);
      newCarbs = roundNutrition((existing.carbs ?? 0) * ratio);
    }

    const [originalFood] =
      existing.foodId && !data.foodId
        ? await this.db
            .select()
            .from(foods)
            .where(eq(foods.id, existing.foodId))
            .limit(1)
        : [undefined];
    const isUserFood =
      originalFood?.source === 'user' && originalFood?.createdBy === userId;
    const needsFork = !!(
      originalFood &&
      !isUserFood &&
      !data.foodId &&
      data.name
    );

    const needTransaction = !!(
      data.name ||
      data.foodId ||
      data.grams !== undefined ||
      data.calories !== undefined ||
      data.protein !== undefined ||
      data.fat !== undefined ||
      data.carbs !== undefined ||
      data.imageUrl ||
      data.date ||
      data.unit !== undefined ||
      data.categoryName !== undefined ||
      needsFork
    );

    if (data.foodId) {
      if (!(await this.findVisibleFood(data.foodId, userId))) {
        throw new NotFoundException('Food not found');
      }
      newFoodId = data.foodId;
    }

    await this.db.transaction(async (tx) => {
      if (needTransaction) {
        if (data.name && !data.foodId) {
          const [matched] = await tx
            .select()
            .from(foods)
            .where(
              and(eq(foods.name, data.name), this.visibilityClause(userId)),
            )
            .limit(1);

          if (matched) {
            newFoodId = matched.id;
          } else if (!matched) {
            if (existing.foodId && (isUserFood || needsFork)) {
              newName = data.name;
            } else {
              const snapGrams =
                existing.grams && existing.grams > 0 ? existing.grams : 0;
              const per100g = (value: number, max: number) =>
                snapGrams > 0
                  ? clampNutrition((value * 100) / snapGrams, max)
                  : 0;

              const [created] = await tx
                .insert(foods)
                .values({
                  name: data.name,
                  source: 'user',
                  createdBy: userId,
                  caloriesPer100g: per100g(existing.calories, 1000),
                  proteinPer100g: per100g(existing.protein ?? 0, 100),
                  fatPer100g: per100g(existing.fat ?? 0, 100),
                  carbsPer100g: per100g(existing.carbs ?? 0, 100),
                })
                .returning();
              newFoodId = created!.id;
              newName = data.name;
              createdFromSnapshot = true;
            }
          }
        }

        if (newFoodId) {
          const [food] = await tx
            .select()
            .from(foods)
            .where(eq(foods.id, newFoodId))
            .limit(1);

          if (food) {
            const g = newGrams ?? 100;
            const ratio = g > 0 ? g / 100 : 1;
            newCalories =
              data.calories ??
              (createdFromSnapshot
                ? newCalories
                : roundNutrition(food.caloriesPer100g * ratio));
            newProtein =
              data.protein ??
              (createdFromSnapshot
                ? newProtein
                : roundNutrition((food.proteinPer100g ?? 0) * ratio));
            newFat =
              data.fat ??
              (createdFromSnapshot
                ? newFat
                : roundNutrition((food.fatPer100g ?? 0) * ratio));
            newCarbs =
              data.carbs ??
              (createdFromSnapshot
                ? newCarbs
                : roundNutrition((food.carbsPer100g ?? 0) * ratio));

            if (needsFork && food.source !== 'user') {
              const per100gRatio = g > 0 ? 100 / g : 1;

              const [forked] = await tx
                .insert(foods)
                .values({
                  name: newName,
                  categoryId: food.categoryId,
                  caloriesPer100g: clampNutrition(newCalories * per100gRatio, 1000),
                  proteinPer100g: clampNutrition(newProtein * per100gRatio, 100),
                  fatPer100g: clampNutrition(newFat * per100gRatio, 100),
                  carbsPer100g: clampNutrition(newCarbs * per100gRatio, 100),
                  imageUrl: newImageUrl,
                  source: 'user',
                  createdBy: userId,
                  forkedFromId: food.id,
                })
                .returning();

              newFoodId = forked!.id;
            } else if (
              newFoodId === existing.foodId &&
              food.source === 'user' &&
              food.createdBy === userId
            ) {
              const foodUpdates: Record<string, unknown> = {};
              if (data.name) foodUpdates.name = data.name;
              if (data.imageUrl) foodUpdates.imageUrl = data.imageUrl;
              if (
                data.calories !== undefined ||
                data.protein !== undefined ||
                data.fat !== undefined ||
                data.carbs !== undefined
              ) {
                const per100gRatio = g > 0 ? 100 / g : 1;
                if (data.calories !== undefined)
                  foodUpdates.caloriesPer100g = clampNutrition(
                    newCalories * per100gRatio,
                    1000,
                  );
                if (data.protein !== undefined)
                  foodUpdates.proteinPer100g = clampNutrition(
                    newProtein * per100gRatio,
                    100,
                  );
                if (data.fat !== undefined)
                  foodUpdates.fatPer100g = clampNutrition(
                    newFat * per100gRatio,
                    100,
                  );
                if (data.carbs !== undefined)
                  foodUpdates.carbsPer100g = clampNutrition(
                    newCarbs * per100gRatio,
                    100,
                  );
              }
              if (Object.keys(foodUpdates).length > 0) {
                foodUpdates.updatedAt = new Date();
                await tx
                  .update(foods)
                  .set(foodUpdates)
                  .where(eq(foods.id, existing.foodId));
              }
            }
          }
        }

        await tx
          .update(foodEntries)
          .set({
            name: newName,
            grams: newGrams,
            unit: newUnit,
            foodId: newFoodId,
            calories: newCalories,
            protein: newProtein,
            fat: newFat,
            carbs: newCarbs,
            imageUrl: newImageUrl,
            entryDate: newEntryDate as any,
            updatedAt: new Date(),
          })
          .where(and(eq(foodEntries.id, id), eq(foodEntries.userId, userId)));
      } else {
        await tx
          .update(foodEntries)
          .set({
            imageUrl: newImageUrl,
            entryDate: newEntryDate as any,
            updatedAt: new Date(),
          })
          .where(and(eq(foodEntries.id, id), eq(foodEntries.userId, userId)));
      }

      if (newFoodId !== existing.foodId && existing.foodId && newFoodId) {
        await tx
          .insert(userFoodStats)
          .values({ userId, foodId: existing.foodId, frequency: 1 })
          .onConflictDoUpdate({
            target: [userFoodStats.userId, userFoodStats.foodId],
            set: {
              frequency: sql`GREATEST(${userFoodStats.frequency} - 1, 0)`,
            },
          });

        await tx
          .insert(userFoodStats)
          .values({ userId, foodId: newFoodId, frequency: 1 })
          .onConflictDoUpdate({
            target: [userFoodStats.userId, userFoodStats.foodId],
            set: {
              frequency: sql`${userFoodStats.frequency} + 1`,
            },
          });
      }

      const calDelta = newCalories - existing.calories;
      const protDelta = newProtein - (existing.protein ?? 0);
      const fatDelta = newFat - (existing.fat ?? 0);
      const carbsDelta = newCarbs - (existing.carbs ?? 0);

      if (existing.entryDate !== newEntryDate) {
        if (
          existing.calories ||
          existing.protein ||
          existing.fat ||
          existing.carbs
        ) {
          await this.dailySummaryService.adjust(
            userId,
            {
              calories: -existing.calories,
              protein: -(existing.protein ?? 0),
              fat: -(existing.fat ?? 0),
              carbs: -(existing.carbs ?? 0),
              date: existing.entryDate ?? undefined,
            },
            tx,
          );
        }
        await this.dailySummaryService.adjust(
          userId,
          {
            calories: newCalories,
            protein: newProtein,
            fat: newFat,
            carbs: newCarbs,
            date: typeof newEntryDate === 'string' ? newEntryDate : undefined,
          },
          tx,
        );
      } else if (calDelta || protDelta || fatDelta || carbsDelta) {
        await this.dailySummaryService.adjust(
          userId,
          {
            calories: calDelta,
            protein: protDelta,
            fat: fatDelta,
            carbs: carbsDelta,
            date: typeof newEntryDate === 'string' ? newEntryDate : undefined,
          },
          tx,
        );
      }

      if (data.categoryName !== undefined && newFoodId) {
        const [food] = await tx
          .select()
          .from(foods)
          .where(eq(foods.id, newFoodId))
          .limit(1);

        // Never alter a shared catalog product. A forked or user-owned food
        // may either receive a category name or be explicitly uncategorized.
        if (food && food.source === 'user' && food.createdBy === userId) {
          if (data.categoryName === null) {
            await tx
              .update(foods)
              .set({ categoryId: null })
              .where(eq(foods.id, newFoodId));
          } else {
            // Same resolution as on create, so a named category is either an
            // existing visible one or a fresh personal one.
            const categoryId = await this.resolveCategory(
              tx,
              userId,
              data.categoryName,
            );

            if (categoryId) {
              await tx
                .update(foods)
                .set({ categoryId })
                .where(eq(foods.id, newFoodId));
            }
          }
        }
      }
    });

    const [updated] = await this.db
      .select()
      .from(foodEntries)
      .where(eq(foodEntries.id, id))
      .limit(1);

    return updated;
  }

  async getAll(limit = 50, offset = 0, userId?: string) {
    const whereClause = userId
      ? or(
          sql`${foods.source} IN ('usda', 'system')`,
          and(eq(foods.source, 'user'), eq(foods.createdBy, userId)),
        )
      : sql`${foods.source} IN ('usda', 'system')`;

    const rows = await this.db
      .select({
        food: foods,
        categoryId: foodCategories.id,
        categoryName: foodCategories.name,
        categoryIcon: foodCategories.icon,
      })
      .from(foods)
      .leftJoin(foodCategories, eq(foods.categoryId, foodCategories.id))
      .where(whereClause)
      .orderBy(foods.name)
      .limit(limit)
      .offset(offset);

    const catMap = new Map<
      string,
      {
        id: string;
        name: string;
        icon: string | null;
        foods: (typeof foods.$inferSelect)[];
      }
    >();

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

  /** Shared catalog categories plus the ones owned by the caller. */
  async getCategories(userId: string) {
    return this.db
      .select()
      .from(foodCategories)
      .where(this.categoryVisibilityClause(userId))
      .orderBy(foodCategories.name);
  }

  async createCategory(userId: string, data: CreateFoodCategoryDto) {
    const name = data.name.trim();

    // A name already taken in either scope would put two look-alike entries in
    // the list the user sees, so both cases are rejected.
    const [clash] = await this.db
      .select({ id: foodCategories.id })
      .from(foodCategories)
      .where(
        and(
          eq(foodCategories.name, name),
          this.categoryVisibilityClause(userId),
        ),
      )
      .limit(1);

    if (clash) {
      throw new ConflictException(`Category "${name}" already exists`);
    }

    const [category] = await this.db
      .insert(foodCategories)
      .values({ name, icon: data.icon, createdBy: userId })
      .returning();

    return category;
  }

  async updateCategory(
    userId: string,
    id: string,
    data: UpdateFoodCategoryDto,
  ) {
    // Same rule as on delete: a system or foreign category must be
    // indistinguishable from a missing one, so ownership is verified before
    // the name clash is even considered.
    const [owned] = await this.db
      .select({ id: foodCategories.id })
      .from(foodCategories)
      .where(this.categoryOwnershipClause(userId, id))
      .limit(1);

    if (!owned) throw new NotFoundException('Category not found');

    const patch: { name?: string; icon?: string | null } = {};

    if (data.name !== undefined) {
      const name = data.name.trim();

      const [clash] = await this.db
        .select({ id: foodCategories.id })
        .from(foodCategories)
        .where(
          and(
            eq(foodCategories.name, name),
            this.categoryVisibilityClause(userId),
            ne(foodCategories.id, id),
          ),
        )
        .limit(1);

      if (clash) {
        throw new ConflictException(`Category "${name}" already exists`);
      }

      patch.name = name;
    }

    if (data.icon !== undefined) patch.icon = data.icon;

    const [updated] = await this.db
      .update(foodCategories)
      .set(patch)
      .where(this.categoryOwnershipClause(userId, id))
      .returning();

    if (!updated) throw new NotFoundException('Category not found');

    return updated;
  }

  async removeCategory(userId: string, id: string) {
    // Ownership is checked first so a system category and someone else's look
    // exactly like a missing one: the reference count must not leak that the
    // row exists and is in use.
    const [owned] = await this.db
      .select({ id: foodCategories.id })
      .from(foodCategories)
      .where(this.categoryOwnershipClause(userId, id))
      .limit(1);

    if (!owned) throw new NotFoundException('Category not found');

    // Products point at the category without a cascade, so the reference count
    // is checked before the delete: letting the foreign key fail would surface
    // as a 500 instead of an explainable conflict.
    const [usage] = await this.db
      .select({ products: count() })
      .from(foods)
      .where(eq(foods.categoryId, id));

    const products = usage?.products ?? 0;

    if (products > 0) {
      throw new ConflictException(
        `Category is used by ${products} product${products === 1 ? '' : 's'}`,
      );
    }

    const [deleted] = await this.db
      .delete(foodCategories)
      .where(this.categoryOwnershipClause(userId, id))
      .returning();

    if (!deleted) throw new NotFoundException('Category not found');

    return deleted;
  }

  // ── Food Catalog ──────────────────────────────────────────────

  async search(query: SearchFoodQueryDto, userId?: string) {
    const { q, limit, offset } = query;

    // Extract weight from the string (hint for the client)
    const weightMatch = q.match(/(\d+([.,]\d+)?)\s*(g|kg|ml|l|oz|lb)\b/i);
    let suggestedGrams: number | null = null;
    let suggestedUnit: string | null = null;

    if (weightMatch?.[1]) {
      const value = parseFloat(weightMatch[1].replace(',', '.'));
      const rawUnit = (weightMatch[3] ?? '').toLowerCase();

      const unitMap: Record<string, { mul: number; display: string }> = {
        g: { mul: 1, display: 'g' },
        kg: { mul: 1000, display: 'g' },
        ml: { mul: 1, display: 'ml' },
        l: { mul: 1000, display: 'ml' },
        oz: { mul: 28.35, display: 'g' },
        lb: { mul: 453.6, display: 'g' },
      };

      const conversion = unitMap[rawUnit];
      if (conversion) {
        suggestedGrams = roundNutrition(value * conversion.mul);
        suggestedUnit = conversion.display;
      }
    }

    // Clean query (weight is stripped from the search)
    const cleanQuery = q
      .toLowerCase()
      .trim()
      .replace(/\b\d+([.,]\d+)?\s?(g|kg|ml|l|oz|lb)\b/gi, '')
      .replace(/[^\p{L}\p{N}\s]/gu, ' ')
      .replace(/\s+/g, ' ')
      .trim();

    const required = offset + limit + FoodService.PRELOAD_PAGE_SIZE;
    const full = await this.buildSearchResults(cleanQuery, userId, required);

    const total = full.length;
    const hasMore = offset + limit < total;
    const foods = full.slice(offset, offset + limit);

    return {
      foods,
      suggestedGrams,
      suggestedUnit,
      total,
      offset,
      limit,
      hasMore,
    };
  }

  /** Full ranked list; fetches more from USDA when local results are few */
  private async buildSearchResults(
    cleanQuery: string,
    userId?: string,
    required = 40,
  ): Promise<OFProduct[]> {
    const term = `%${cleanQuery}%`;
    const visibilityClause = userId
      ? or(
          sql`${foods.source} IN ('usda', 'system')`,
          and(eq(foods.source, 'user'), eq(foods.createdBy, userId)),
        )
      : sql`${foods.source} IN ('usda', 'system')`;

    const localRows = await this.db
      .select({
        food: foods,
        categoryName: foodCategories.name,
      })
      .from(foods)
      .leftJoin(foodCategories, eq(foods.categoryId, foodCategories.id))
      .where(
        and(
          visibilityClause,
          or(
            sql`to_tsvector('simple', ${foods.name}) @@ plainto_tsquery('simple', ${cleanQuery})`,
            sql`${foods.name} ILIKE ${term}`,
            sql`${foods.barcode} LIKE ${term}`,
          ),
        ),
      );

    const localIds = localRows.map((r) => r.food.id);

    const localServings = localIds.length
      ? await this.db
          .select()
          .from(foodServings)
          .where(
            and(
              inArray(foodServings.foodId, localIds),
              this.servingVisibilityClause(userId),
            ),
          )
      : [];

    // How often this user picks each item — used for ranking
    const freqMap = new Map<string, number>();
    if (userId && localIds.length) {
      const stats = await this.db
        .select({
          foodId: userFoodStats.foodId,
          frequency: userFoodStats.frequency,
        })
        .from(userFoodStats)
        .where(
          and(
            eq(userFoodStats.userId, userId),
            inArray(userFoodStats.foodId, localIds),
          ),
        );
      for (const s of stats) freqMap.set(s.foodId, s.frequency ?? 0);
    }

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
        createdAt:
          f.createdAt instanceof Date
            ? f.createdAt.toISOString()
            : String(f.createdAt),
        updatedAt:
          f.updatedAt instanceof Date
            ? f.updatedAt.toISOString()
            : String(f.updatedAt),
        frequency: freqMap.get(f.id) ?? 0,
        servings: localServings
          .filter((s) => s.foodId === f.id)
          .map((s) => ({
            id: s.id,
            foodId: s.foodId,
            name: s.name,
            grams: s.grams,
            createdAt:
              s.createdAt instanceof Date ? s.createdAt.toISOString() : null,
          })),
      };
    });

    // Rank the DB results
    const localRanked = this.rank(local, cleanQuery, userId);
    const enoughLocal = localRanked.length >= required;

    if (enoughLocal) {
      return localRanked;
    }

    // USDA is optional enrichment. A shared deadline covers both queueing and
    // network work, so an unavailable third party never makes food search slow.
    const [srLegacyRes, brandedRes] =
      await this.searchUSDAWithinDeadline(cleanQuery);

    const srItems: OFProduct[] =
      srLegacyRes.status === 'fulfilled' ? srLegacyRes.value : [];
    const brandedItems: OFProduct[] =
      brandedRes.status === 'fulfilled' ? brandedRes.value : [];

    const allUsda = [...srItems, ...brandedItems];

    // Dedup (locals go before external results)
    const merged = [...localRanked, ...allUsda];
    const deduped = this.deduplicate(merged);

    return this.rank(deduped, cleanQuery, userId);
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
      .replace(/\b(cheese|food|product|pack|piece|slices|slice|block)\b/g, '')
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

  private async searchUSDAWithinDeadline(
    query: string,
  ): Promise<
    [PromiseSettledResult<OFProduct[]>, PromiseSettledResult<OFProduct[]>]
  > {
    const signal = AbortSignal.timeout(env.USDA_SEARCH_TIMEOUT_MS);
    const searches = Promise.allSettled([
      this.searchUSDA(query, 25, 'SR Legacy', signal),
      this.searchUSDA(query, 25, 'Branded', signal),
    ]);

    try {
      return await Promise.race([
        searches,
        new Promise<never>((_resolve, reject) => {
          signal.addEventListener('abort', () => reject(signal.reason), {
            once: true,
          });
        }),
      ]);
    } catch {
      return [
        { status: 'rejected', reason: signal.reason },
        { status: 'rejected', reason: signal.reason },
      ];
    }
  }

  private async rateLimitedFetch(
    url: string,
    signal: AbortSignal,
  ): Promise<Response> {
    const previous = this.usdaQueue;
    const queued = previous.then(async () => {
      if (signal.aborted) throw signal.reason;
      await this.delayWithSignal(250, signal);
      return fetch(url, { signal });
    });

    // Keep the rate-limit queue alive after an external failure or timeout.
    this.usdaQueue = queued.then(
      () => undefined,
      () => undefined,
    );
    return queued;
  }

  private delayWithSignal(milliseconds: number, signal: AbortSignal) {
    return new Promise<void>((resolve, reject) => {
      const timer = setTimeout(resolve, milliseconds);
      signal.addEventListener(
        'abort',
        () => {
          clearTimeout(timer);
          reject(signal.reason);
        },
        { once: true },
      );
    });
  }

  private async searchUSDA(
    query: string,
    pageSize: number,
    dataType: string,
    signal: AbortSignal,
  ): Promise<OFProduct[]> {
    const cacheKey = this.usdaCacheKey(query, dataType);
    const cached = await this.redis.get(cacheKey);
    if (cached) {
      const products = this.parseCachedUSDA(cached);
      if (products) return products;
      await this.redis.delete(cacheKey);
    }

    const url = new URL('https://api.nal.usda.gov/fdc/v1/foods/search');
    url.searchParams.set('api_key', env.USDA_API_KEY);
    url.searchParams.set('query', query);
    url.searchParams.set('pageSize', String(pageSize));
    url.searchParams.set('dataType', dataType);

    const res = await this.rateLimitedFetch(url.toString(), signal);
    if (!res.ok) {
      console.error(
        `[USDA] ${dataType} returned ${res.status}: ${res.statusText}`,
      );
      return [];
    }

    const body = (await res.json()) as {
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

    const products = body.foods
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

    await this.redis.set(
      cacheKey,
      JSON.stringify(products),
      env.USDA_SEARCH_CACHE_TTL_MS,
    );
    return products;
  }

  private usdaCacheKey(query: string, dataType: string) {
    return `nutriflow:usda-search:v1:${encodeURIComponent(query)}:${encodeURIComponent(dataType)}`;
  }

  private parseCachedUSDA(value: string): OFProduct[] | null {
    try {
      const parsed: unknown = JSON.parse(value);
      if (
        !Array.isArray(parsed) ||
        !parsed.every(
          (item) =>
            typeof item === 'object' &&
            item !== null &&
            typeof item.name === 'string' &&
            typeof item.source === 'string',
        )
      ) {
        return null;
      }
      return parsed as OFProduct[];
    } catch {
      return null;
    }
  }

  private extractNutrient(
    nutrients: Array<{ nutrientId: number; value?: number }> | undefined,
    id: number,
  ): number {
    return roundNutrition(
      nutrients?.find((n) => n.nutrientId === id)?.value ?? 0,
    );
  }

  async getPopular(userId: string) {
    const results = await this.db
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

  async getByBarcode(barcode: string, userId: string) {
    const [food] = await this.db
      .select()
      .from(foods)
      .where(and(eq(foods.barcode, barcode), this.visibilityClause(userId)))
      .orderBy(
        sql`CASE WHEN ${foods.source} = 'user' AND ${foods.createdBy} = ${userId} THEN 0 ELSE 1 END`,
      )
      .limit(1);

    if (!food) return null;

    const servings = await this.listServings(food.id, userId);

    return { ...food, servings };
  }

  async getById(id: string, userId: string) {
    const food = await this.findVisibleFood(id, userId);
    if (!food) throw new NotFoundException('Food not found');

    const servings = await this.listServings(id, userId);

    return { ...food, servings };
  }

  // ── Servings (portions of a product) ─────────────────────────

  /**
   * Adds a personal portion to any visible product, catalog ones included.
   * Catalog portions stay untouched and read-only for everyone.
   */
  async addServing(
    userId: string,
    foodId: string,
    data: CreateFoodServingDto,
  ): Promise<FoodServing> {
    const food = await this.findVisibleFood(foodId, userId);
    if (!food) throw new NotFoundException('Food not found');

    await this.assertServingNameFree(foodId, userId, data.name);

    const [serving] = await this.db
      .insert(foodServings)
      .values({
        foodId,
        name: data.name,
        grams: data.grams,
        source: SERVING_SOURCE_USER,
        createdBy: userId,
      })
      .returning();

    return serving!;
  }

  async updateServing(
    userId: string,
    foodId: string,
    servingId: string,
    data: UpdateFoodServingDto,
  ): Promise<FoodServing> {
    if (data.name !== undefined) {
      await this.assertServingNameFree(foodId, userId, data.name, servingId);
    }

    const [updated] = await this.db
      .update(foodServings)
      .set({
        ...(data.name !== undefined ? { name: data.name } : {}),
        ...(data.grams !== undefined ? { grams: data.grams } : {}),
      })
      .where(this.servingOwnershipClause(userId, foodId, servingId))
      .returning();

    // A catalog portion or someone else's portion reports as missing: a 403
    // would confirm rows the caller must not learn about.
    if (!updated) throw new NotFoundException('Serving not found');

    return updated;
  }

  async removeServing(userId: string, foodId: string, servingId: string) {
    const [deleted] = await this.db
      .delete(foodServings)
      .where(this.servingOwnershipClause(userId, foodId, servingId))
      .returning({ id: foodServings.id });

    if (!deleted) throw new NotFoundException('Serving not found');

    return { id: servingId };
  }

  /** Portions are identified by name inside one product, per owner scope. */
  private async assertServingNameFree(
    foodId: string,
    userId: string,
    name: string,
    excludeServingId?: string,
  ) {
    const conditions = [
      eq(foodServings.foodId, foodId),
      eq(foodServings.source, SERVING_SOURCE_USER),
      eq(foodServings.createdBy, userId),
      eq(foodServings.name, name),
    ];

    if (excludeServingId) {
      conditions.push(sql`${foodServings.id} <> ${excludeServingId}`);
    }

    const [duplicate] = await this.db
      .select({ id: foodServings.id })
      .from(foodServings)
      .where(and(...conditions))
      .limit(1);

    if (duplicate) throw new ConflictException('Serving already exists');
  }

  async createFood(userId: string, data: CreateFoodDto) {
    const result = await this.db.transaction(async (tx) => {
      if (data.categoryId) {
        await this.assertVisibleCategory(tx, userId, data.categoryId);
      }

      const [food] = await tx
        .insert(foods)
        .values({
          name: data.name,
          categoryId: data.categoryId,
          caloriesPer100g: data.caloriesPer100g,
          proteinPer100g: data.proteinPer100g ?? 0,
          fatPer100g: data.fatPer100g ?? 0,
          carbsPer100g: data.carbsPer100g ?? 0,
          barcode: data.barcode,
          imageUrl: data.imageUrl,
          source: 'user',
          createdBy: userId,
        })
        .returning();

      if (!food) throw new Error('Failed to create food');

      if (data.servings?.length) {
        await tx.insert(foodServings).values(
          data.servings.map((s) => ({
            foodId: food.id,
            name: s.name,
            grams: s.grams,
          })),
        );
      }

      const servings = await this.listServings(food.id, userId, tx);

      return { ...food, servings };
    });

    return result;
  }

  /** Records a user's product pick/add so frequently chosen items
   *  float higher (used in search and popular lists). */
  async trackSelection(userId: string, foodId: string) {
    const food = await this.findVisibleFood(foodId, userId);

    if (!food) throw new NotFoundException('Food not found');

    await this.db
      .insert(userFoodStats)
      .values({ userId, foodId, frequency: 1 })
      .onConflictDoUpdate({
        target: [userFoodStats.userId, userFoodStats.foodId],
        set: {
          frequency: sql`${userFoodStats.frequency} + 1`,
          lastUsedAt: sql`NOW()`,
        },
      });

    return { ok: true };
  }

  // ── Dedup (3 levels) ─────────────────────────────────────────

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

  private rank(
    items: OFProduct[],
    query: string,
    userId?: string,
  ): OFProduct[] {
    const qLower = query.toLowerCase();
    const qWords = qLower.split(/\s+/).filter((w) => w.length > 0);
    const isMine = (item: OFProduct) =>
      item.source === 'user' && !!userId && item.createdBy === userId;

    return items
      .map((item) => {
        const nameLower = item.name.toLowerCase();
        let score = 0;

        // Source priority: my own products always float to the top
        if (isMine(item)) score += 100;
        else if (item.source === 'system') score += 5;
        else if (item.source === 'usda_sr') score += 4;
        else if (item.source === 'usda') score += 3;

        // Frequently picked by this user — floats higher
        if (userId && (item.frequency ?? 0) > 0) {
          score += Math.min(item.frequency ?? 0, 20) / 2;
        }

        // Match against the query
        if (nameLower === qLower) score += 50;
        else if (nameLower.startsWith(qLower)) score += 30;
        else if (nameLower.includes(qLower)) score += 10;

        for (const qw of qWords) {
          if (
            nameLower.split(/\s+/).some((nw) => nw === qw || nw.startsWith(qw))
          ) {
            score += 0.5;
          }
        }

        // Card quality
        if (item.imageUrl) score += 3;
        if (item.brand) score += 2;
        if (item.servings?.length) score += 2;

        return { ...item, score };
      })
      .sort((a, b) => {
        const diff = (b.score ?? 0) - (a.score ?? 0);
        if (diff !== 0) return diff;
        // Stability: on equal score — alphabetical, then by name
        return a.name.localeCompare(b.name);
      });
  }
}
