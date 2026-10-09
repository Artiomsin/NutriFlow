import {
  pgSchema,
  uuid,
  varchar,
  integer,
  timestamp,
  check,
} from 'drizzle-orm/pg-core';
import { foods } from './foods';
import { sql } from 'drizzle-orm';

const app = pgSchema('app');

export const foodServings = app.table('food_servings', {
  id: uuid('id').primaryKey().defaultRandom(),

  foodId: uuid('food_id')
    .notNull()
    .references(() => foods.id, { onDelete: 'cascade' }),

  name: varchar('name', { length: 100 }).notNull(),

  grams: integer('grams').notNull(),

  createdAt: timestamp('created_at').defaultNow().notNull(),
}, (table) => ({
  validServing: check(
    'food_servings_valid_serving',
    sql`char_length(trim(${table.name})) > 0 AND ${table.grams} >= 0 AND ${table.grams} <= 10000`,
  ),
}));

export type FoodServing = typeof foodServings.$inferSelect;
export type NewFoodServing = typeof foodServings.$inferInsert;
