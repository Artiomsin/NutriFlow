import {
  pgSchema,
  uuid,
  integer,
  numeric,
  timestamp,
  date,
  uniqueIndex,
  check,
} from 'drizzle-orm/pg-core';
import { users } from './users';
import { sql } from 'drizzle-orm';

const app = pgSchema('app');

export const dailyActivity = app.table(
  'daily_activity',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    date: date('date').notNull(),
    steps: integer('steps').default(0).notNull(),
    activeCalories: integer('active_calories').default(0).notNull(),
    basalCalories: integer('basal_calories').default(0).notNull(),
    distanceMeters: numeric('distance_meters', {
      precision: 10,
      scale: 2,
    }).default('0'),
    createdAt: timestamp('created_at').defaultNow().notNull(),
    updatedAt: timestamp('updated_at')
      .defaultNow()
      .$onUpdate(() => new Date())
      .notNull(),
  },
  (table) => ({
    userDateUnique: uniqueIndex('daily_activity_user_date_key').on(
      table.userId,
      table.date,
    ),
    metricRanges: check(
      'daily_activity_metric_ranges',
      sql`${table.steps} >= 0 AND ${table.steps} <= 200000
        AND ${table.activeCalories} >= 0 AND ${table.activeCalories} <= 20000
        AND ${table.basalCalories} >= 0 AND ${table.basalCalories} <= 20000
        AND ${table.distanceMeters} >= 0 AND ${table.distanceMeters} <= 1000000`,
    ),
  }),
);

export type DailyActivity = typeof dailyActivity.$inferSelect;
export type NewDailyActivity = typeof dailyActivity.$inferInsert;
