import {
  pgSchema,
  uuid,
  varchar,
  integer,
  numeric,
  jsonb,
  timestamp,
  uniqueIndex,
} from 'drizzle-orm/pg-core';
import { users } from './users';

const app = pgSchema('app');

export const userProfiles = app.table('user_profiles', {
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

  preferredUnits: jsonb('preferred_units').$type<{
    weight: 'metric' | 'imperial';
    volume: 'metric' | 'imperial';
    energy: 'kcal' | 'kj';
  }>().default({ weight: 'metric', volume: 'metric', energy: 'kcal' }).notNull(),

  createdAt: timestamp('created_at').defaultNow().notNull(),

  updatedAt: timestamp('updated_at')
    .defaultNow()
    .$onUpdate(() => new Date())
    .notNull(),
}, (table) => ({
  userIdUnique: uniqueIndex('idx_user_profiles_user_id_unique').on(table.userId),
}));

export type UserProfile = typeof userProfiles.$inferSelect;
export type NewUserProfile = typeof userProfiles.$inferInsert;