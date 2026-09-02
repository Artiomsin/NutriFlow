import {
  pgSchema,
  uuid,
  varchar,
  timestamp,
} from 'drizzle-orm/pg-core';

const app = pgSchema('app');

export const users = app.table('users', {
  id: uuid('id').primaryKey().defaultRandom(),

  email: varchar('email', { length: 120 }).notNull().unique(),

  passwordHash: varchar('password_hash', { length: 255 }),

  googleId: varchar('google_id', { length: 255 }).unique(),

  appleId: varchar('apple_id', {length: 255}).unique(),

  firstName: varchar('first_name', { length: 50 }),
  
  lastName: varchar('last_name', { length: 50 }),

  avatarUrl: varchar('avatar_url', { length: 500 }),

  createdAt: timestamp('created_at').defaultNow().notNull(),

  updatedAt: timestamp('updated_at')
    .defaultNow()
    .$onUpdate(() => new Date())
    .notNull(),
});

export type User = typeof users.$inferSelect;
export type NewUser = typeof users.$inferInsert;
