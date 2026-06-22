import {
  pgSchema,
  uuid,
  varchar,
  boolean,
  timestamp,
} from 'drizzle-orm/pg-core';

const app = pgSchema('app');

export const users = app.table('users', {
  id: uuid('id').primaryKey().defaultRandom(),

  email: varchar('email', { length: 120 }).notNull().unique(),

  passwordHash: varchar('password_hash', { length: 255 }).notNull(),

  firstName: varchar('first_name', { length: 50 }),
  
  lastName: varchar('last_name', { length: 50 }),

  createdAt: timestamp('created_at').defaultNow().notNull(),

  updatedAt: timestamp('updated_at')
    .defaultNow()
    .$onUpdate(() => new Date())
    .notNull(),
});

export type User = typeof users.$inferSelect;
export type NewUser = typeof users.$inferInsert;
