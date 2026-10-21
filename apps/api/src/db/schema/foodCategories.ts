import {
  check,
  index,
  pgSchema,
  uniqueIndex,
  uuid,
  varchar,
  timestamp,
} from 'drizzle-orm/pg-core';
import { sql } from 'drizzle-orm';
import { users } from './users';

const app = pgSchema('app');

export const foodCategories = app.table(
  'food_categories',
  {
    id: uuid('id').primaryKey().defaultRandom(),

    name: varchar('name', { length: 100 }).notNull(),

    icon: varchar('icon', { length: 50 }),

    // Owner of a personal category. `NULL` marks a shared catalog category
    // that only the project owner maintains.
    createdBy: uuid('created_by').references(() => users.id, {
      onDelete: 'cascade',
    }),

    createdAt: timestamp('created_at').defaultNow().notNull(),
  },
  (table) => ({
    // System categories keep a name unique among themselves, while a personal
    // category only has to be unique for its owner. A single global unique on
    // `name` would stop two users from both having "My breakfasts".
    systemNameUnique: uniqueIndex('uq_category_system_name')
      .on(table.name)
      .where(sql`${table.createdBy} IS NULL`),
    userNameUnique: uniqueIndex('uq_category_user_name')
      .on(table.createdBy, table.name)
      .where(sql`${table.createdBy} IS NOT NULL`),
    createdByIdx: index('idx_food_categories_created_by').on(table.createdBy),
    nonBlankName: check(
      'food_categories_non_blank_name',
      sql`char_length(trim(${table.name})) > 0`,
    ),
  }),
);

export type FoodCategory = typeof foodCategories.$inferSelect;
export type NewFoodCategory = typeof foodCategories.$inferInsert;
