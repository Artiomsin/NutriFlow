import {
  pgSchema, uuid, varchar, numeric, timestamp, jsonb, boolean, integer, uniqueIndex, index,
} from 'drizzle-orm/pg-core';
import { users } from './users';

const app = pgSchema('app');

export const userWorkouts = app.table('user_workouts', {
  id: uuid('id').primaryKey().defaultRandom(),
  userId: uuid('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),
  healthKitWorkoutId: varchar('healthkit_workout_id', { length: 64 }).notNull(),
  type: varchar('type', { length: 50 }).notNull(),
  startDate: timestamp('start_date', { withTimezone: true }).notNull(),
  endDate: timestamp('end_date', { withTimezone: true }).notNull(),
  durationSeconds: numeric('duration_seconds', { precision: 10, scale: 3 }).notNull(),
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
  elevationGainMeters: numeric('elevation_gain_meters', { precision: 10, scale: 2 }),
  steps: integer('steps'),
  indoor: boolean('indoor'),
  details: jsonb('details').default({}).notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at')
    .defaultNow()
    .$onUpdate(() => new Date())
    .notNull(),
}, (table) => ({
  userWorkoutUnique: uniqueIndex('user_workouts_user_workout_key').on(table.userId, table.healthKitWorkoutId),
  userStartIndex: index('user_workouts_user_start_idx').on(table.userId, table.startDate),
}));

export type UserWorkout = typeof userWorkouts.$inferSelect;
export type NewUserWorkout = typeof userWorkouts.$inferInsert;