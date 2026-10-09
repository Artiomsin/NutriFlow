import {
  pgSchema,
  uuid,
  varchar,
  integer,
  numeric,
  jsonb,
  timestamp,
  uniqueIndex,
  check,
} from 'drizzle-orm/pg-core';
import { sql } from 'drizzle-orm';
import { users } from './users';

const app = pgSchema('app');

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
    goal: varchar('goal', { length: 20 }),
    activityLevel: varchar('activity_level', { length: 20 }),
    timeZone: varchar('time_zone', { length: 64 }).notNull().default('UTC'),

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
  }),
);

export type UserProfile = typeof userProfiles.$inferSelect;
export type NewUserProfile = typeof userProfiles.$inferInsert;
