import { sql } from 'drizzle-orm';
import {
  pgSchema,
  uuid,
  varchar,
  numeric,
  timestamp,
  index,
  uniqueIndex,
  foreignKey,
  check,
} from 'drizzle-orm/pg-core';
import { users } from './users';
import { foodCategories } from './foodCategories';

const app = pgSchema('app');

export const foods = app.table(
  'foods',
  {
    id: uuid('id').primaryKey().defaultRandom(),

    name: varchar('name', { length: 255 }).notNull(),

    // A deleted personal category must not make its products undeletable.
    // The product keeps its nutrition snapshot but becomes uncategorized.
    categoryId: uuid('category_id').references(() => foodCategories.id, {
      onDelete: 'set null',
    }),

    caloriesPer100g: numeric('calories_per_100g', {
      precision: 10,
      scale: 1,
      mode: 'number',
    }).notNull(),
    proteinPer100g: numeric('protein_per_100g', {
      precision: 10,
      scale: 1,
      mode: 'number',
    }).default(0),
    fatPer100g: numeric('fat_per_100g', {
      precision: 10,
      scale: 1,
      mode: 'number',
    }).default(0),
    carbsPer100g: numeric('carbs_per_100g', {
      precision: 10,
      scale: 1,
      mode: 'number',
    }).default(0),

    barcode: varchar('barcode', { length: 50 }),

    imageUrl: varchar('image_url', { length: 500 }),

    brand: varchar('brand', { length: 200 }),

    source: varchar('source', { length: 20 }).notNull().default('user'),

    forkedFromId: uuid('forked_from_id'),

    createdBy: uuid('created_by').references(() => users.id, {
      onDelete: 'cascade',
    }),

    createdAt: timestamp('created_at').defaultNow().notNull(),
    updatedAt: timestamp('updated_at')
      .defaultNow()
      .$onUpdate(() => new Date())
      .notNull(),
  },
  (table) => ({
    nameFtsIdx: index('idx_foods_name_fts').using(
      'gin',
      sql`to_tsvector('simple', ${table.name})`,
    ),
    // Product names are descriptive rather than identifiers. Private products
    // and catalog products may legitimately share the same name.
    catalogBarcodeUnique: uniqueIndex('uq_catalog_foods_barcode')
      .on(table.barcode)
      .where(
        sql`${table.barcode} IS NOT NULL AND ${table.source} IN ('system', 'usda')`,
      ),
    categoryIdIdx: index('idx_foods_category_id').on(table.categoryId),
    forkedFromFk: foreignKey({
      columns: [table.forkedFromId],
      foreignColumns: [table.id],
    }).onDelete('set null'),
    nutrientRanges: check(
      'foods_nutrient_ranges',
      sql`${table.caloriesPer100g} >= 0 AND ${table.caloriesPer100g} <= 1000
        AND ${table.proteinPer100g} >= 0 AND ${table.proteinPer100g} <= 100
        AND ${table.fatPer100g} >= 0 AND ${table.fatPer100g} <= 100
        AND ${table.carbsPer100g} >= 0 AND ${table.carbsPer100g} <= 100`,
    ),
    sourceValues: check(
      'foods_source_values',
      sql`${table.source} IN ('user', 'system', 'usda')`,
    ),
    ownerRequired: check(
      'foods_owner_required',
      sql`(${table.source} = 'user') = (${table.createdBy} IS NOT NULL)`,
    ),
  }),
);

export type Food = typeof foods.$inferSelect;
export type NewFood = typeof foods.$inferInsert;
