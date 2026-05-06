import {
  pgSchema,
  uuid,
  varchar,
  integer,
  timestamp,
} from 'drizzle-orm/pg-core';
import { users } from './users';

const app = pgSchema('app');

export const foodEntries = app.table('food_entries', {
  id: uuid('id').primaryKey().defaultRandom(),

  userId: uuid('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),

  name: varchar('name', { length: 120 }).notNull(),

  calories: integer('calories').notNull(),
  protein: integer('protein').default(0),
  fat: integer('fat').default(0),
  carbs: integer('carbs').default(0),

  createdAt: timestamp('created_at').defaultNow().notNull(),
});

export type FoodEntry = typeof foodEntries.$inferSelect;
export type NewFoodEntry = typeof foodEntries.$inferInsert;