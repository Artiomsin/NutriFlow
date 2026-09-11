import {
  pgSchema, uuid, integer, numeric, timestamp, date, uniqueIndex,
} from 'drizzle-orm/pg-core';
import { users } from './users';

const app = pgSchema('app');

export const dailyActivity = app.table('daily_activity', {
  id: uuid('id').primaryKey().defaultRandom(),
  userId: uuid('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),
  date: date('date').notNull(),
  steps: integer('steps').default(0).notNull(),
  activeCalories: integer('active_calories').default(0).notNull(),
  basalCalories: integer('basal_calories').default(0).notNull(),
  distanceMeters: numeric('distance_meters', { precision: 10, scale: 2 }).default('0'),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at')
    .defaultNow()
    .$onUpdate(() => new Date())
    .notNull(),
}, (table) => ({
  userDateUnique: uniqueIndex('daily_activity_user_date_key').on(table.userId, table.date),
}));

export type DailyActivity = typeof dailyActivity.$inferSelect;
export type NewDailyActivity = typeof dailyActivity.$inferInsert;