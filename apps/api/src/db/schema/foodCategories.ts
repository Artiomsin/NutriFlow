import { check, pgSchema, uuid, varchar, timestamp } from 'drizzle-orm/pg-core';
import { sql } from 'drizzle-orm';

const app = pgSchema('app');

export const foodCategories = app.table('food_categories', {
  id: uuid('id').primaryKey().defaultRandom(),

  name: varchar('name', { length: 100 }).notNull().unique(),

  icon: varchar('icon', { length: 50 }),

  createdAt: timestamp('created_at').defaultNow().notNull(),
}, (table) => ({
  nonBlankName: check(
    'food_categories_non_blank_name',
    sql`char_length(trim(${table.name})) > 0`,
  ),
}));

export type FoodCategory = typeof foodCategories.$inferSelect;
export type NewFoodCategory = typeof foodCategories.$inferInsert;
