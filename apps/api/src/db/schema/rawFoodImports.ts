import {
  pgSchema,
  uuid,
  varchar,
  jsonb,
  timestamp,
} from 'drizzle-orm/pg-core';
import { foods } from './foods';

const app = pgSchema('app');

export const rawFoodImports = app.table('raw_food_imports', {
  id: uuid('id').primaryKey().defaultRandom(),

  foodId: uuid('food_id').references(() => foods.id),

  barcode: varchar('barcode', { length: 50 }),

  source: varchar('source', { length: 20 }).notNull(),

  rawData: jsonb('raw_data').notNull(),

  status: varchar('status', { length: 20 }).notNull().default('pending'),

  createdAt: timestamp('created_at').defaultNow().notNull(),
});

export type RawFoodImport = typeof rawFoodImports.$inferSelect;
export type NewRawFoodImport = typeof rawFoodImports.$inferInsert;
