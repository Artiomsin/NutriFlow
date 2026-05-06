import {
  pgSchema,
  uuid,
  integer,
  timestamp,
} from 'drizzle-orm/pg-core';
import { users } from './users';

const app = pgSchema('app');

export const waterEntries = app.table('water_entries', {
  id: uuid('id').primaryKey().defaultRandom(),

  userId: uuid('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),

  amountMl: integer('amount_ml').notNull(),

  createdAt: timestamp('created_at').defaultNow().notNull(),
});

export type WaterEntry = typeof waterEntries.$inferSelect;
export type NewWaterEntry = typeof waterEntries.$inferInsert;