import {
  pgSchema,
  uuid,
  integer,
  timestamp,
  date,
  index,
  check,
} from 'drizzle-orm/pg-core';
import { sql } from 'drizzle-orm';
import { users } from './users';

const app = pgSchema('app');

export const waterEntries = app.table(
  'water_entries',
  {
    id: uuid('id').primaryKey().defaultRandom(),

    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),

    amountMl: integer('amount_ml').notNull(),

    entryDate: date('entry_date').notNull(),

    createdAt: timestamp('created_at', { withTimezone: true })
      .defaultNow()
      .notNull(),
  },
  (table) => ({
    userDateIdx: index('idx_water_entries_user_date').on(
      table.userId,
      table.entryDate,
    ),
    amountRange: check(
      'water_entries_amount_range',
      sql`${table.amountMl} >= 1 AND ${table.amountMl} <= 3000`,
    ),
  }),
);

export type WaterEntry = typeof waterEntries.$inferSelect;
export type NewWaterEntry = typeof waterEntries.$inferInsert;
