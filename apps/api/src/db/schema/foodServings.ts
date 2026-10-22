import {
  pgSchema,
  uuid,
  varchar,
  integer,
  timestamp,
  index,
  check,
} from 'drizzle-orm/pg-core';
import { foods } from './foods';
import { users } from './users';
import { sql } from 'drizzle-orm';

const app = pgSchema('app');

/** Catalog portion: readable by everyone who may see the food, read-only. */
export const SERVING_SOURCE_SYSTEM = 'system';

/** Personal portion: readable and editable only by `createdBy`. */
export const SERVING_SOURCE_USER = 'user';

export const foodServings = app.table(
  'food_servings',
  {
    id: uuid('id').primaryKey().defaultRandom(),

    foodId: uuid('food_id')
      .notNull()
      .references(() => foods.id, { onDelete: 'cascade' }),

    name: varchar('name', { length: 100 }).notNull(),

    grams: integer('grams').notNull(),

    source: varchar('source', { length: 10 })
      .notNull()
      .default(SERVING_SOURCE_SYSTEM),

    createdBy: uuid('created_by').references(() => users.id, {
      onDelete: 'cascade',
    }),

    createdAt: timestamp('created_at').defaultNow().notNull(),
  },
  (table) => ({
    foodIdIdx: index('idx_food_servings_food_id').on(table.foodId),
    sourceValues: check(
      'food_servings_source_values',
      sql`${table.source} IN ('system', 'user')`,
    ),
    // A personal portion only makes sense together with its owner, and a
    // catalog portion must never carry one.
    ownerRequired: check(
      'food_servings_owner_required',
      sql`(${table.source} = 'user') = (${table.createdBy} IS NOT NULL)`,
    ),
    validServing: check(
      'food_servings_valid_serving',
      sql`char_length(trim(${table.name})) > 0 AND ${table.grams} >= 0 AND ${table.grams} <= 10000`,
    ),
  }),
);

export type FoodServing = typeof foodServings.$inferSelect;
export type NewFoodServing = typeof foodServings.$inferInsert;
