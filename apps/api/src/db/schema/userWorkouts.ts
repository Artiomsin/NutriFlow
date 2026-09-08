import {
  pgSchema, uuid, varchar, numeric, timestamp, uniqueIndex, index,
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
  source: varchar('source', { length: 10 }).default('healthkit'),
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