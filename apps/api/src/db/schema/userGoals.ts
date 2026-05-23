import { pgSchema, uuid, integer, varchar, timestamp } from 'drizzle-orm/pg-core';
import { users } from './users';

const app = pgSchema('app');
export const userGoals = app.table('user_goals', {
  id: uuid('id').primaryKey().defaultRandom(),
  userId: uuid('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' })
    .unique(),
  dailyCaloriesGoal: integer('daily_calories_goal'),
  dailyProteinGoal: integer('daily_protein_goal'),
  dailyFatGoal: integer('daily_fat_goal'),
  dailyCarbsGoal: integer('daily_carbs_goal'),
  dailyWaterGoal: integer('daily_water_goal'),
  source: varchar('source', { length: 10 }).default('auto'),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at')
    .defaultNow()
    .$onUpdate(() => new Date())
    .notNull(),
});
export type UserGoals = typeof userGoals.$inferSelect;
export type NewUserGoals = typeof userGoals.$inferInsert;