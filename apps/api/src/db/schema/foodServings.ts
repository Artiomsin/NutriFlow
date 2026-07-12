import {
  pgSchema,
  uuid,
  varchar,
  integer,
  timestamp,
} from 'drizzle-orm/pg-core';
import { foods } from './foods';

const app = pgSchema('app');

export const foodServings = app.table('food_servings', {
  id: uuid('id').primaryKey().defaultRandom(),

  foodId: uuid('food_id')
    .notNull()
    .references(() => foods.id, { onDelete: 'cascade' }),

  name: varchar('name', { length: 100 }).notNull(),

  grams: integer('grams').notNull(),

  createdAt: timestamp('created_at').defaultNow().notNull(),
});

export type FoodServing = typeof foodServings.$inferSelect;
export type NewFoodServing = typeof foodServings.$inferInsert;
