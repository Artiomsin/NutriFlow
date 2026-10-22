import { sql } from 'drizzle-orm';
import {
  check,
  index,
  pgSchema,
  timestamp,
  uuid,
  varchar,
} from 'drizzle-orm/pg-core';
import { users } from './users';

const app = pgSchema('app');

/** A single food-photo analysis slot in a rolling 24-hour quota window. */
export const analysisQuotaReservations = app.table(
  'analysis_quota_reservations',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    status: varchar('status', { length: 10 })
      .$type<'pending' | 'consumed'>()
      .notNull(),
    reservedAt: timestamp('reserved_at', { withTimezone: true })
      .defaultNow()
      .notNull(),
    expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
  },
  (table) => ({
    userExpiryIndex: index('idx_analysis_quota_reservations_user_expiry').on(
      table.userId,
      table.expiresAt,
    ),
    validStatus: check(
      'analysis_quota_reservations_valid_status',
      sql`${table.status} IN ('pending', 'consumed')`,
    ),
  }),
);

export type AnalysisQuotaReservation =
  typeof analysisQuotaReservations.$inferSelect;
