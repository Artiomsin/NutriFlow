import { sql } from 'drizzle-orm';
import {
  pgSchema,
  uuid,
  varchar,
  integer,
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

    categoryId: uuid('category_id').references(() => foodCategories.id),

    caloriesPer100g: integer('calories_per_100g').notNull(),
    proteinPer100g: integer('protein_per_100g').default(0),
    fatPer100g: integer('fat_per_100g').default(0),
    carbsPer100g: integer('carbs_per_100g').default(0),

    barcode: varchar('barcode', { length: 50 }),

    imageUrl: varchar('image_url', { length: 500 }),

    brand: varchar('brand', { length: 200 }),

    source: varchar('source', { length: 20 }).notNull().default('user'),

    forkedFromId: uuid('forked_from_id'),

    createdBy: uuid('created_by').references(() => users.id, {
      onDelete: 'set null',
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
  }),
);

export type Food = typeof foods.$inferSelect;
export type NewFood = typeof foods.$inferInsert;
