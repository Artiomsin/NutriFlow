import {
  pgSchema,
  uuid,
  varchar,
  integer,
  numeric,
  timestamp,
} from 'drizzle-orm/pg-core';
import { users } from './users';

const app = pgSchema('app');

export const userProfiles = app.table('user_profiles', {
  id: uuid('id').primaryKey().defaultRandom(),

  userId: uuid('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),

  weight: numeric('weight', { precision: 5, scale: 2 }),
  height: integer('height'),
  age: integer('age'),

  goal: varchar('goal', { length: 20 }),
  activityLevel: varchar('activity_level', { length: 20 }),

  createdAt: timestamp('created_at').defaultNow().notNull(),

  updatedAt: timestamp('updated_at')
    .defaultNow()
    .$onUpdate(() => new Date())
    .notNull(),
});

export type UserProfile = typeof userProfiles.$inferSelect;
export type NewUserProfile = typeof userProfiles.$inferInsert;