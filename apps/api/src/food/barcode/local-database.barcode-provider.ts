import { Inject, Injectable } from '@nestjs/common';
import { and, desc, eq, inArray, or, sql } from 'drizzle-orm';

import type { Db } from '../../db/db';
import { DB } from '../../db/db.module';
import { foodCategories } from '../../db/schema/foodCategories';
import {
  foodServings,
  SERVING_SOURCE_SYSTEM,
  SERVING_SOURCE_USER,
} from '../../db/schema/foodServings';
import { foods } from '../../db/schema/foods';
import {
  BarcodeLookupProvider,
  type BarcodeProduct,
} from './barcode-lookup.provider';
import { barcodeVariants } from './gtin';

/**
 * Looks up products already stored in the NutriFlow database:
 * - the current user's own products (source='user', createdBy=user)
 * - the shared catalog (source='system')
 * - USDA imports (source='usda')
 *
 * Visibility rules match the rest of the food service. A user's personal
 * product is never returned to anybody else.
 */
@Injectable()
export class LocalDatabaseBarcodeProvider extends BarcodeLookupProvider {
  readonly name = 'local-database';
  readonly priority = 10;
  /** May return personal products, so a shared miss is not authoritative. */
  override readonly scope = 'user';

  constructor(@Inject(DB) private readonly db: Db) {
    super();
  }

  async lookup(
    gtin14: string,
    userId?: string,
  ): Promise<BarcodeProduct | null> {
    const barcodes = barcodeVariants(gtin14);
    if (barcodes.length === 0) {
      return null;
    }

    const visibility = userId
      ? or(
          sql`${foods.source} IN ('usda', 'system')`,
          and(eq(foods.source, 'user'), eq(foods.createdBy, userId)),
        )
      : sql`${foods.source} IN ('usda', 'system')`;

    const [row] = await this.db
      .select({
        food: foods,
        categoryName: foodCategories.name,
      })
      .from(foods)
      .leftJoin(foodCategories, eq(foods.categoryId, foodCategories.id))
      .where(and(inArray(foods.barcode, barcodes), visibility))
      .orderBy(
        // The user's own product wins over a shared one with the same barcode.
        userId
          ? sql`CASE WHEN ${foods.source} = 'user' AND ${foods.createdBy} = ${userId} THEN 0 ELSE 1 END`
          : sql`1`,
        // Then the curated catalog, then imported USDA records.
        sql`CASE WHEN ${foods.source} = 'system' THEN 0 ELSE 1 END`,
        // Duplicates are allowed; pick the freshest one deterministically.
        desc(foods.updatedAt),
      )
      .limit(1);

    if (!row) {
      return null;
    }

    const f = row.food;
    return {
      id: f.id,
      name: f.name,
      brand: f.brand ?? null,
      categoryName: row.categoryName ?? null,
      caloriesPer100g: Number(f.caloriesPer100g),
      proteinPer100g:
        f.proteinPer100g === null ? undefined : Number(f.proteinPer100g),
      fatPer100g: f.fatPer100g === null ? undefined : Number(f.fatPer100g),
      carbsPer100g:
        f.carbsPer100g === null ? undefined : Number(f.carbsPer100g),
      barcode: f.barcode ?? gtin14,
      imageUrl: f.imageUrl ?? null,
      source: f.source,
      createdBy: f.createdBy ?? null,
      servings: await this.listServings(f.id, userId),
    };
  }

  /** Catalog portions plus the current user's personal portions. */
  private async listServings(foodId: string, userId?: string) {
    const visibility = userId
      ? or(
          eq(foodServings.source, SERVING_SOURCE_SYSTEM),
          and(
            eq(foodServings.source, SERVING_SOURCE_USER),
            eq(foodServings.createdBy, userId),
          ),
        )
      : eq(foodServings.source, SERVING_SOURCE_SYSTEM);

    return this.db
      .select({
        id: foodServings.id,
        name: foodServings.name,
        grams: foodServings.grams,
      })
      .from(foodServings)
      .where(and(eq(foodServings.foodId, foodId), visibility))
      .orderBy(foodServings.grams);
  }
}
