import {
  pgSchema,
  uuid,
  varchar,
  integer,
  numeric,
  date,
  jsonb,
  timestamp,
  uniqueIndex,
  check,
} from 'drizzle-orm/pg-core';
import { sql } from 'drizzle-orm';
import { users } from './users';

const app = pgSchema('app');

export type ProfileGoalType = 'lose' | 'gain' | 'maintain';

export const userProfiles = app.table(
  'user_profiles',
  {
    id: uuid('id').primaryKey().defaultRandom(),

    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),

    weight: numeric('weight', {
      precision: 5,
      scale: 2,
      mode: 'number',
    }),

    height: integer('height'),
    age: integer('age'),
    gender: varchar('gender', { length: 10 }),
    goal: varchar('goal', { length: 20 }).$type<ProfileGoalType>(),
    activityLevel: varchar('activity_level', { length: 20 }),
    timeZone: varchar('time_zone', { length: 64 }).notNull().default('UTC'),

    // Measurable goal (optional). Used to personalize calories/pace and progress.
    targetWeightKg: numeric('target_weight_kg', {
      precision: 5,
      scale: 2,
      mode: 'number',
    }),
    // Maintain range (preferred for maintain). targetWeightKg remains as
    // optional center/anchor for backward compatibility.
    targetWeightMinKg: numeric('target_weight_min_kg', {
      precision: 5,
      scale: 2,
      mode: 'number',
    }),
    targetWeightMaxKg: numeric('target_weight_max_kg', {
      precision: 5,
      scale: 2,
      mode: 'number',
    }),
    // Signed kg/week from start toward target direction is allowed by convention
    // in service logic; stored as absolute magnitude by default.
    weeklyRateKg: numeric('weekly_rate_kg', {
      precision: 4,
      scale: 2,
      mode: 'number',
    }),
    targetDate: date('target_date'),
    goalStartedAt: timestamp('goal_started_at', { withTimezone: true }),

    preferredUnits: jsonb('preferred_units')
      .$type<{
        weight: 'metric' | 'imperial';
        volume: 'metric' | 'imperial';
        energy: 'kcal' | 'kj';
      }>()
      .default({ weight: 'metric', volume: 'metric', energy: 'kcal' })
      .notNull(),

    createdAt: timestamp('created_at').defaultNow().notNull(),

    updatedAt: timestamp('updated_at')
      .defaultNow()
      .$onUpdate(() => new Date())
      .notNull(),
  },
  (table) => ({
    userIdUnique: uniqueIndex('idx_user_profiles_user_id_unique').on(
      table.userId,
    ),
    validMeasurements: check(
      'user_profiles_valid_measurements',
      sql`(${table.weight} IS NULL OR (${table.weight} >= 20 AND ${table.weight} <= 400))
        AND (${table.height} IS NULL OR (${table.height} >= 50 AND ${table.height} <= 300))
        AND (${table.age} IS NULL OR (${table.age} >= 1 AND ${table.age} <= 120))`,
    ),
    allowedValues: check(
      'user_profiles_allowed_values',
      sql`(${table.gender} IS NULL OR ${table.gender} IN ('male', 'female'))
        AND (${table.goal} IS NULL OR ${table.goal} IN ('lose', 'gain', 'maintain'))
        AND (${table.activityLevel} IS NULL OR ${table.activityLevel} IN ('low', 'medium', 'high'))`,
    ),
    validTargets: check(
      'user_profiles_valid_targets',
      sql`(${table.targetWeightKg} IS NULL OR (${table.targetWeightKg} >= 20 AND ${table.targetWeightKg} <= 400))
        AND (${table.targetWeightMinKg} IS NULL OR (${table.targetWeightMinKg} >= 20 AND ${table.targetWeightMinKg} <= 400))
        AND (${table.targetWeightMaxKg} IS NULL OR (${table.targetWeightMaxKg} >= 20 AND ${table.targetWeightMaxKg} <= 400))
        AND (${table.targetWeightMinKg} IS NULL OR ${table.targetWeightMaxKg} IS NULL OR ${table.targetWeightMinKg} < ${table.targetWeightMaxKg})
        AND (${table.weeklyRateKg} IS NULL OR (${table.weeklyRateKg} > 0 AND ${table.weeklyRateKg} <= 2))`,
    ),
  }),
);

export type UserProfile = typeof userProfiles.$inferSelect;
export type NewUserProfile = typeof userProfiles.$inferInsert;
