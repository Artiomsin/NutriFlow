import {
  pgSchema,
  uuid,
  varchar,
  integer,
  timestamp,
} from 'drizzle-orm/pg-core';
import { users } from './users';
import { foodCategories } from './foodCategories';

const app = pgSchema('app');

export const foods = app.table('foods', {
  id: uuid('id').primaryKey().defaultRandom(),

  name: varchar('name', { length: 255 }).notNull(),

  categoryId: uuid('category_id').references(() => foodCategories.id),

  caloriesPer100g: integer('calories_per_100g').notNull(),
  proteinPer100g: integer('protein_per_100g').default(0),
  fatPer100g: integer('fat_per_100g').default(0),
  carbsPer100g: integer('carbs_per_100g').default(0),

  barcode: varchar('barcode', { length: 50 }).unique(),

  imageUrl: varchar('image_url', { length: 500 }),

  source: varchar('source', { length: 20 }).notNull().default('user'),

  createdBy: uuid('created_by').references(() => users.id),

  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at')
    .defaultNow()
    .$onUpdate(() => new Date())
    .notNull(),
});

export type Food = typeof foods.$inferSelect;
export type NewFood = typeof foods.$inferInsert;
