import {
  pgSchema,
  uuid,
  numeric,
  date,
  varchar,
  timestamp,
  index,
  uniqueIndex,
} from 'drizzle-orm/pg-core';
import { users } from './users';

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
  }),
);

export type WeightLog = typeof weightLogs.$inferSelect;
export type NewWeightLog = typeof weightLogs.$inferInsert;