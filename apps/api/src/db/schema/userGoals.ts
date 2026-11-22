import {
  pgSchema,
  uuid,
  integer,
  numeric,
  varchar,
  timestamp,
  jsonb,
  check,
  index,
  uniqueIndex,
} from 'drizzle-orm/pg-core';
import { users } from './users';
import { sql } from 'drizzle-orm';
import type { GoalMetrics } from '../../goals/personalization/types';

const app = pgSchema('app');

export type GoalSource = 'initial' | 'user' | 'personalized';
export type GoalMode = 'auto' | 'manual';

export type GoalMetricKey = keyof GoalMetrics;

export interface ManualGoalOverride {
  value: number;
  setAt: string;
}

export type ManualGoalOverrides = Partial<
  Record<GoalMetricKey, ManualGoalOverride>
>;

export interface GoalSuggestion {
  goals: GoalMetrics;
  reason: string;
  suggestedAt: string;
  basis?: Record<string, unknown> | null;
}

export interface GoalAppliedBasis {
  currentWeightKg?: number | null;
  profile?: Record<string, unknown> | null;
  target?: Record<string, unknown> | null;
  [key: string]: unknown;
}

export const userGoals = app.table(
  'user_goals',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    // Nutrition
    dailyCaloriesGoal: numeric('daily_calories_goal', {
      precision: 10,
      scale: 1,
      mode: 'number',
    }),
    dailyProteinGoal: numeric('daily_protein_goal', {
      precision: 10,
      scale: 1,
      mode: 'number',
    }),
    dailyFatGoal: numeric('daily_fat_goal', {
      precision: 10,
      scale: 1,
      mode: 'number',
    }),
    dailyCarbsGoal: numeric('daily_carbs_goal', {
      precision: 10,
      scale: 1,
      mode: 'number',
    }),
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

    mode: varchar('mode', { length: 10 })
      .$type<GoalMode>()
      .default('auto')
      .notNull(),

    source: varchar('source', { length: 20 })
      .$type<GoalSource>()
      .default('initial'),
    // Why this version replaced the previous one. Nullable because versions
    // created before the column existed have no reason recorded.
    changeReason: varchar('change_reason', { length: 100 }),

    // Pending auto-calculated suggestion for manual mode (or informational).
    suggestedGoals: jsonb('suggested_goals').$type<GoalMetrics>(),
    suggestionReason: varchar('suggestion_reason', { length: 100 }),
    suggestedAt: timestamp('suggested_at', { withTimezone: true }),
    suggestionBasis: jsonb('suggestion_basis').$type<Record<string, unknown>>(),
    appliedBasis: jsonb('applied_basis').$type<GoalAppliedBasis>(),
    manualOverrides: jsonb('manual_overrides').$type<ManualGoalOverrides>(),

    createdAt: timestamp('created_at').defaultNow().notNull(),
    updatedAt: timestamp('updated_at')
      .defaultNow()
      .$onUpdate(() => new Date())
      .notNull(),
    startedAt: timestamp('started_at', { withTimezone: true })
      .defaultNow()
      .notNull(),
    endedAt: timestamp('ended_at', { withTimezone: true }),
  },
  (table) => ({
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
    modeValues: check(
      'user_goals_mode_values',
      sql`${table.mode} IN ('auto', 'manual')`,
    ),
    userIdIdx: index('idx_user_goals_user_id').on(table.userId),

    userPeriodIdx: index('idx_user_goals_user_period').on(
      table.userId,
      table.startedAt,
      table.endedAt,
    ),

    oneActiveGoalPerUser: uniqueIndex('idx_user_goals_one_active_per_user')
      .on(table.userId)
      .where(sql`${table.endedAt} IS NULL`),
  }),
);
export type UserGoals = typeof userGoals.$inferSelect;
export type NewUserGoals = typeof userGoals.$inferInsert;
