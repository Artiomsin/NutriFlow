import {
  pgSchema,
  uuid,
  integer,
  varchar,
  timestamp,
  check,
} from 'drizzle-orm/pg-core';
import { users } from './users';
import { sql } from 'drizzle-orm';

const app = pgSchema('app');

export type GoalSource = 'initial' | 'user' | 'personalized';
export const userGoals = app.table('user_goals', {
  id: uuid('id').primaryKey().defaultRandom(),
  userId: uuid('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' })
    .unique(),
  // Nutrition
  dailyCaloriesGoal: integer('daily_calories_goal'),
  dailyProteinGoal: integer('daily_protein_goal'),
  dailyFatGoal: integer('daily_fat_goal'),
  dailyCarbsGoal: integer('daily_carbs_goal'),
  dailyWaterGoal: integer('daily_water_goal'),

  // Activity
  dailyStepsGoal: integer('daily_steps_goal'),
  dailyActiveCaloriesGoal: integer('daily_active_calories_goal'),

  // Workout
  weeklyWorkoutsGoal: integer('weekly_workouts_goal'),
  weeklyWorkoutMinutesGoal: integer('weekly_workout_minutes_goal'),

  // Sleep
  nightlySleepMinMinutes: integer('nightly_sleep_min_minutes'),
  nightlySleepMaxMinutes: integer('nightly_sleep_max_minutes'),

  source: varchar('source', { length: 20 })
    .$type<GoalSource>()
    .default('initial'),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at')
    .defaultNow()
    .$onUpdate(() => new Date())
    .notNull(),
}, (table) => ({
  positiveGoals: check(
    'user_goals_positive_values',
    sql`(${table.dailyCaloriesGoal} IS NULL OR ${table.dailyCaloriesGoal} > 0)
      AND (${table.dailyProteinGoal} IS NULL OR ${table.dailyProteinGoal} > 0)
      AND (${table.dailyFatGoal} IS NULL OR ${table.dailyFatGoal} > 0)
      AND (${table.dailyCarbsGoal} IS NULL OR ${table.dailyCarbsGoal} > 0)
      AND (${table.dailyWaterGoal} IS NULL OR ${table.dailyWaterGoal} > 0)
      AND (${table.dailyStepsGoal} IS NULL OR ${table.dailyStepsGoal} > 0)
      AND (${table.dailyActiveCaloriesGoal} IS NULL OR ${table.dailyActiveCaloriesGoal} > 0)
      AND (${table.weeklyWorkoutsGoal} IS NULL OR ${table.weeklyWorkoutsGoal} > 0)
      AND (${table.weeklyWorkoutMinutesGoal} IS NULL OR ${table.weeklyWorkoutMinutesGoal} > 0)
      AND (${table.nightlySleepMinMinutes} IS NULL OR ${table.nightlySleepMinMinutes} > 0)
      AND (${table.nightlySleepMaxMinutes} IS NULL OR ${table.nightlySleepMaxMinutes} > 0)`,
  ),
  sleepRange: check(
    'user_goals_sleep_range',
    sql`${table.nightlySleepMinMinutes} IS NULL OR ${table.nightlySleepMaxMinutes} IS NULL
      OR ${table.nightlySleepMinMinutes} <= ${table.nightlySleepMaxMinutes}`,
  ),
  sourceValues: check(
    'user_goals_source_values',
    sql`${table.source} IN ('initial', 'user', 'personalized')`,
  ),
}));
export type UserGoals = typeof userGoals.$inferSelect;
export type NewUserGoals = typeof userGoals.$inferInsert;
