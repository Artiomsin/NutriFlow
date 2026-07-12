import {
  pgSchema,
  uuid,
  varchar,
  timestamp,
} from 'drizzle-orm/pg-core';

const app = pgSchema('app');

export const foodCategories = app.table('food_categories', {
  id: uuid('id').primaryKey().defaultRandom(),

  name: varchar('name', { length: 100 }).notNull().unique(),

  icon: varchar('icon', { length: 50 }),

  createdAt: timestamp('created_at').defaultNow().notNull(),
});

export type FoodCategory = typeof foodCategories.$inferSelect;
export type NewFoodCategory = typeof foodCategories.$inferInsert;
