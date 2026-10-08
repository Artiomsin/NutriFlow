import {
  pgSchema,
  uuid,
  numeric,
  date,
  varchar,
  timestamp,
  index,
  uniqueIndex,
  check,
} from 'drizzle-orm/pg-core';
import { users } from './users';
import { sql } from 'drizzle-orm';

const app = pgSchema('app');

export const weightLogs = app.table(
  'weight_logs',
  {
    id: uuid('id').primaryKey().defaultRandom(),

    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),

    weightKg: numeric('weight_kg', { precision: 5, scale: 2 }).notNull(),

    entryDate: date('entry_date').notNull(),

    source: varchar('source', { length: 10 }).default('manual').notNull(),

    createdAt: timestamp('created_at', { withTimezone: true })
      .defaultNow()
      .notNull(),

    updatedAt: timestamp('updated_at', { withTimezone: true })
      .defaultNow()
      .$onUpdate(() => new Date())
      .notNull(),
  },
  (table) => ({
    userDateUnique: uniqueIndex('uq_weight_logs_user_date').on(
      table.userId,
      table.entryDate,
    ),
    userDateIdx: index('idx_weight_logs_user_date').on(
      table.userId,
      table.entryDate,
    ),
    weightRange: check(
      'weight_logs_weight_range',
      sql`${table.weightKg} >= 20 AND ${table.weightKg} <= 400`,
    ),
    sourceValues: check(
      'weight_logs_source_values',
      sql`${table.source} IN ('initial', 'manual')`,
    ),
  }),
);

export type WeightLog = typeof weightLogs.$inferSelect;
export type NewWeightLog = typeof weightLogs.$inferInsert;
