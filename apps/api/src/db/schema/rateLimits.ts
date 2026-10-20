import {
  index,
  integer,
  pgSchema,
  timestamp,
  varchar,
} from 'drizzle-orm/pg-core';

const app = pgSchema('app');

/**
 * Short-lived request counters used by the PostgreSQL throttler storage.
 * The key is a SHA-256 hash, never a raw IP address or user ID.
 */
export const rateLimits = app.table(
  'rate_limits',
  {
    key: varchar('key', { length: 64 }).primaryKey(),
    totalHits: integer('total_hits').notNull().default(0),
    expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
  },
  (table) => ({
    expiresAtIndex: index('idx_rate_limits_expires_at').on(table.expiresAt),
  }),
);

export type RateLimit = typeof rateLimits.$inferSelect;
