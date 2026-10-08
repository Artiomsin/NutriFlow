import {
  pgSchema,
  uuid,
  varchar,
  integer,
  timestamp,
  date,
  index,
  check,
} from 'drizzle-orm/pg-core';
import { sql } from 'drizzle-orm';
import { users } from './users';
import { foods } from './foods';

const app = pgSchema('app');

export const foodEntries = app.table(
  'food_entries',
  {
    id: uuid('id').primaryKey().defaultRandom(),

    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),

    foodId: uuid('food_id').references(() => foods.id),

    name: varchar('name', { length: 120 }).notNull(),

    grams: integer('grams'),

    unit: varchar('unit', { length: 10 }).notNull().default('g'),

    calories: integer('calories').notNull(),
    protein: integer('protein').default(0),
    fat: integer('fat').default(0),
    carbs: integer('carbs').default(0),

    imageUrl: varchar('image_url', { length: 500 }),

    entryDate: date('entry_date').notNull(),

    createdAt: timestamp('created_at', { withTimezone: true })
      .defaultNow()
      .notNull(),
    updatedAt: timestamp('updated_at', { withTimezone: true })
      .defaultNow()
      .$onUpdate(() => new Date())
      .notNull(),
  },
  (table) => ({
    userDateIdx: index('idx_food_entries_user_date').on(
      table.userId,
      table.entryDate,
    ),
    valueRanges: check(
      'food_entries_value_ranges',
      sql`(${table.grams} IS NULL OR (${table.grams} >= 0 AND ${table.grams} <= 10000))
        AND ${table.calories} >= 0 AND ${table.calories} <= 5000
        AND ${table.protein} >= 0 AND ${table.protein} <= 1000
        AND ${table.fat} >= 0 AND ${table.fat} <= 1000
        AND ${table.carbs} >= 0 AND ${table.carbs} <= 1000`,
    ),
  }),
);

export type FoodEntry = typeof foodEntries.$inferSelect;
export type NewFoodEntry = typeof foodEntries.$inferInsert;
