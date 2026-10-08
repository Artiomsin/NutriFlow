import {
  pgSchema,
  uuid,
  timestamp,
  numeric,
  integer,
  date,
  uniqueIndex,
  check,
} from 'drizzle-orm/pg-core';
import { users } from './users';
import { sql } from 'drizzle-orm';

const app = pgSchema('app');

export const userSleep = app.table(
  'user_sleep',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),

    startDate: timestamp('start_date', { withTimezone: true }).notNull(),
    endDate: timestamp('end_date', { withTimezone: true }).notNull(),
    localDate: date('local_date').notNull(),

    timeInBedSeconds: numeric('time_in_bed_seconds', {
      precision: 12,
      scale: 1,
    }),
    asleepSeconds: numeric('asleep_seconds', { precision: 12, scale: 1 }),
    awakeSeconds: numeric('awake_seconds', { precision: 12, scale: 1 }),
    coreSeconds: numeric('core_seconds', { precision: 12, scale: 1 }),
    deepSeconds: numeric('deep_seconds', { precision: 12, scale: 1 }),
    remSeconds: numeric('rem_seconds', { precision: 12, scale: 1 }),
    unspecifiedSeconds: numeric('unspecified_seconds', {
      precision: 12,
      scale: 1,
    }),

    awakenings: integer('awakenings'),
    onsetLatencySeconds: numeric('onset_latency_seconds', {
      precision: 12,
      scale: 1,
    }),
    efficiency: numeric('efficiency', { precision: 5, scale: 2 }),
    segmentCount: integer('segment_count'),

    heartRateAvg: numeric('heart_rate_avg', { precision: 5, scale: 1 }),

    createdAt: timestamp('created_at').defaultNow().notNull(),
    updatedAt: timestamp('updated_at')
      .defaultNow()
      .$onUpdate(() => new Date())
      .notNull(),
  },
  (table) => ({
    userDateUnique: uniqueIndex('user_sleep_user_start_key').on(
      table.userId,
      table.startDate,
    ),
    validTiming: check(
      'user_sleep_valid_timing',
      sql`${table.endDate} > ${table.startDate}`,
    ),
    metricRanges: check(
      'user_sleep_metric_ranges',
      sql`(${table.timeInBedSeconds} IS NULL OR (${table.timeInBedSeconds} >= 0 AND ${table.timeInBedSeconds} <= 86400))
        AND (${table.asleepSeconds} IS NULL OR (${table.asleepSeconds} >= 0 AND ${table.asleepSeconds} <= 86400))
        AND (${table.awakeSeconds} IS NULL OR (${table.awakeSeconds} >= 0 AND ${table.awakeSeconds} <= 86400))
        AND (${table.coreSeconds} IS NULL OR (${table.coreSeconds} >= 0 AND ${table.coreSeconds} <= 86400))
        AND (${table.deepSeconds} IS NULL OR (${table.deepSeconds} >= 0 AND ${table.deepSeconds} <= 86400))
        AND (${table.remSeconds} IS NULL OR (${table.remSeconds} >= 0 AND ${table.remSeconds} <= 86400))
        AND (${table.unspecifiedSeconds} IS NULL OR (${table.unspecifiedSeconds} >= 0 AND ${table.unspecifiedSeconds} <= 86400))
        AND (${table.awakenings} IS NULL OR ${table.awakenings} >= 0)
        AND (${table.onsetLatencySeconds} IS NULL OR ${table.onsetLatencySeconds} >= 0)
        AND (${table.efficiency} IS NULL OR (${table.efficiency} >= 0 AND ${table.efficiency} <= 100))
        AND (${table.segmentCount} IS NULL OR ${table.segmentCount} >= 0)
        AND (${table.heartRateAvg} IS NULL OR (${table.heartRateAvg} >= 0 AND ${table.heartRateAvg} <= 300))`,
    ),
  }),
);

export type UserSleep = typeof userSleep.$inferSelect;
export type NewUserSleep = typeof userSleep.$inferInsert;
