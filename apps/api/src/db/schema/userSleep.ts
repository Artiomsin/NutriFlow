import {
  pgSchema, uuid, timestamp, numeric, integer, uniqueIndex,
} from 'drizzle-orm/pg-core';
import { users } from './users';

const app = pgSchema('app');

export const userSleep = app.table('user_sleep', {
  id: uuid('id').primaryKey().defaultRandom(),
  userId: uuid('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),

  startDate: timestamp('start_date', { withTimezone: true }).notNull(),
  endDate: timestamp('end_date', { withTimezone: true }).notNull(),

  timeInBedSeconds: numeric('time_in_bed_seconds', { precision: 12, scale: 1 }),
  asleepSeconds: numeric('asleep_seconds', { precision: 12, scale: 1 }),
  awakeSeconds: numeric('awake_seconds', { precision: 12, scale: 1 }),
  coreSeconds: numeric('core_seconds', { precision: 12, scale: 1 }),
  deepSeconds: numeric('deep_seconds', { precision: 12, scale: 1 }),
  remSeconds: numeric('rem_seconds', { precision: 12, scale: 1 }),
  unspecifiedSeconds: numeric('unspecified_seconds', { precision: 12, scale: 1 }),

  awakenings: integer('awakenings'),
  onsetLatencySeconds: numeric('onset_latency_seconds', { precision: 12, scale: 1 }),
  efficiency: numeric('efficiency', { precision: 5, scale: 2 }),
  segmentCount: integer('segment_count'),

  heartRateAvg: numeric('heart_rate_avg', { precision: 5, scale: 1 }),

  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at').defaultNow().$onUpdate(() => new Date()).notNull(),
}, (table) => ({
  userDateUnique: uniqueIndex('user_sleep_user_start_key').on(table.userId, table.startDate),
}));

export type UserSleep = typeof userSleep.$inferSelect;
export type NewUserSleep = typeof userSleep.$inferInsert;