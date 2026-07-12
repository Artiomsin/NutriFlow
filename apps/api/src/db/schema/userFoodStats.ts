import {
  pgSchema,
  uuid,
  integer,
  timestamp,
  uniqueIndex,
} from 'drizzle-orm/pg-core';
import { users } from './users';
import { foods } from './foods';

const app = pgSchema('app');

export const userFoodStats = app.table('user_food_stats', {
  id: uuid('id').primaryKey().defaultRandom(),

  userId: uuid('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),

  foodId: uuid('food_id')
    .notNull()
    .references(() => foods.id, { onDelete: 'cascade' }),

  frequency: integer('frequency').default(0),

  lastUsedAt: timestamp('last_used_at').defaultNow(),

  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at')
    .defaultNow()
    .$onUpdate(() => new Date())
    .notNull(),
}, (table) => ({
  userFoodIdx: uniqueIndex().on(table.userId, table.foodId),
}));

export type UserFoodStat = typeof userFoodStats.$inferSelect;
export type NewUserFoodStat = typeof userFoodStats.$inferInsert;
