import {
  pgSchema,
  uuid,
  varchar,
  numeric,
  timestamp,
  jsonb,
  boolean,
  integer,
  uniqueIndex,
  index,
  date,
  check,
} from 'drizzle-orm/pg-core';
import { users } from './users';
import { sql } from 'drizzle-orm';

const app = pgSchema('app');

export const userWorkouts = app.table(
  'user_workouts',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    healthKitWorkoutId: varchar('healthkit_workout_id', {
      length: 64,
    }).notNull(),
    type: varchar('type', { length: 50 }).notNull(),
    startDate: timestamp('start_date', { withTimezone: true }).notNull(),
    endDate: timestamp('end_date', { withTimezone: true }).notNull(),
    localDate: date('local_date').notNull(),
    durationSeconds: numeric('duration_seconds', {
      precision: 10,
      scale: 3,
    }).notNull(),
    caloriesBurned: numeric('calories_burned', { precision: 10, scale: 2 }),
    distanceMeters: numeric('distance_meters', { precision: 10, scale: 2 }),
    heartRateAvg: numeric('heart_rate_avg', { precision: 5, scale: 1 }),
    heartRateMax: numeric('heart_rate_max', { precision: 5, scale: 1 }),
    heartRateMin: numeric('heart_rate_min', { precision: 5, scale: 1 }),
    avgSpeedMps: numeric('avg_speed_mps', { precision: 10, scale: 2 }),
    maxSpeedMps: numeric('max_speed_mps', { precision: 10, scale: 2 }),
    avgCadence: numeric('avg_cadence', { precision: 10, scale: 2 }),
    maxCadence: numeric('max_cadence', { precision: 10, scale: 2 }),
    avgPowerWatts: numeric('avg_power_watts', { precision: 10, scale: 2 }),
    maxPowerWatts: numeric('max_power_watts', { precision: 10, scale: 2 }),
    elevationGainMeters: numeric('elevation_gain_meters', {
      precision: 10,
      scale: 2,
    }),
    steps: integer('steps'),
    indoor: boolean('indoor'),
    details: jsonb('details').default({}).notNull(),
    createdAt: timestamp('created_at').defaultNow().notNull(),
    updatedAt: timestamp('updated_at')
      .defaultNow()
      .$onUpdate(() => new Date())
      .notNull(),
  },
  (table) => ({
    userWorkoutUnique: uniqueIndex('user_workouts_user_workout_key').on(
      table.userId,
      table.healthKitWorkoutId,
    ),
    userStartIndex: index('user_workouts_user_start_idx').on(
      table.userId,
      table.startDate,
    ),
    validTiming: check(
      'user_workouts_valid_timing',
      sql`${table.endDate} > ${table.startDate} AND ${table.durationSeconds} >= 0
        AND ${table.durationSeconds} <= 86400`,
    ),
    nonNegativeMetrics: check(
      'user_workouts_non_negative_metrics',
      sql`(${table.caloriesBurned} IS NULL OR ${table.caloriesBurned} >= 0)
        AND (${table.distanceMeters} IS NULL OR ${table.distanceMeters} >= 0)
        AND (${table.heartRateAvg} IS NULL OR (${table.heartRateAvg} >= 0 AND ${table.heartRateAvg} <= 300))
        AND (${table.heartRateMax} IS NULL OR (${table.heartRateMax} >= 0 AND ${table.heartRateMax} <= 300))
        AND (${table.heartRateMin} IS NULL OR (${table.heartRateMin} >= 0 AND ${table.heartRateMin} <= 300))
        AND (${table.steps} IS NULL OR ${table.steps} >= 0)`,
    ),
  }),
);

export type UserWorkout = typeof userWorkouts.$inferSelect;
export type NewUserWorkout = typeof userWorkouts.$inferInsert;
