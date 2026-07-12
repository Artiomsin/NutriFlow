import {
  pgSchema,
  uuid,
  integer,
  timestamp,
  date,
  index,
} from 'drizzle-orm/pg-core';
import { users } from './users';

const app = pgSchema('app');

export const waterEntries = app.table('water_entries', {
  id: uuid('id').primaryKey().defaultRandom(),

  userId: uuid('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),

  amountMl: integer('amount_ml').notNull(),

  entryDate: date('entry_date'),

  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
}, (table) => ({
  userDateIdx: index('idx_water_entries_user_date').on(table.userId, table.entryDate),
}));

export type WaterEntry = typeof waterEntries.$inferSelect;
export type NewWaterEntry = typeof waterEntries.$inferInsert;