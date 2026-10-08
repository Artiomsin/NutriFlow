import {
  index,
  pgSchema,
  timestamp,
  uniqueIndex,
  uuid,
  varchar,
  check,
} from 'drizzle-orm/pg-core';
import { sql } from 'drizzle-orm';
import { users } from './users';

const app = pgSchema('app');

/**
 * A server-side refresh-token session. Keeping sessions in PostgreSQL makes
 * logout and refresh-token revocation work across all Vercel instances.
 */
export const authSessions = app.table(
  'auth_sessions',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    sessionId: uuid('session_id').notNull(),
    refreshTokenHash: varchar('refresh_token_hash', { length: 64 }).notNull(),
    previousRefreshTokenHash: varchar('previous_refresh_token_hash', {
      length: 64,
    }),
    previousValidUntil: timestamp('previous_valid_until', {
      withTimezone: true,
    }),
    expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
    revokedAt: timestamp('revoked_at', { withTimezone: true }),
    createdAt: timestamp('created_at', { withTimezone: true })
      .defaultNow()
      .notNull(),
    updatedAt: timestamp('updated_at', { withTimezone: true })
      .defaultNow()
      .$onUpdate(() => new Date())
      .notNull(),
  },
  (table) => ({
    sessionIdUnique: uniqueIndex('uq_auth_sessions_session_id').on(
      table.sessionId,
    ),
    userIdIdx: index('idx_auth_sessions_user_id').on(table.userId),
    validExpiry: check(
      'auth_sessions_valid_expiry',
      sql`${table.expiresAt} > ${table.createdAt}`,
    ),
  }),
);

export type AuthSession = typeof authSessions.$inferSelect;
export type NewAuthSession = typeof authSessions.$inferInsert;
