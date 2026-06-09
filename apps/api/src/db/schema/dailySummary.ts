import {
  pgSchema,
  uuid,
  integer,
  timestamp,
  date,
  uniqueIndex,
} from 'drizzle-orm/pg-core';
import { users } from './users';

const app = pgSchema('app');

export const dailySummary = app.table('daily_summary', {
  id: uuid('id').primaryKey().defaultRandom(),

  userId: uuid('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),

  date: date('date').notNull(),

  totalCalories: integer('total_calories').default(0),
  totalProtein: integer('total_protein').default(0),
  totalFat: integer('total_fat').default(0),
  totalCarbs: integer('total_carbs').default(0),
  totalWaterMl: integer('total_water_ml').default(0),

  createdAt: timestamp('created_at').defaultNow().notNull(),
}, (table) => ({
  userDateUnique: uniqueIndex('daily_summary_user_date_key').on(table.userId, table.date),
}));

export type DailySummary = typeof dailySummary.$inferSelect;
export type NewDailySummary = typeof dailySummary.$inferInsert;