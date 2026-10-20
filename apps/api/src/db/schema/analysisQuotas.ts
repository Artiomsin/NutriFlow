import {
  date,
  index,
  integer,
  pgSchema,
  uniqueIndex,
  uuid,
} from 'drizzle-orm/pg-core';
import { users } from './users';

const app = pgSchema('app');

/** A durable per-user daily allowance for paid food-photo analysis. */
export const analysisQuotas = app.table(
  'analysis_quotas',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    date: date('date').notNull(),
    count: integer('count').notNull().default(0),
  },
  (table) => ({
    dateIndex: index('idx_analysis_quotas_date').on(table.date),
    userDateUnique: uniqueIndex('uq_analysis_quotas_user_date').on(
      table.userId,
      table.date,
    ),
  }),
);

export type AnalysisQuota = typeof analysisQuotas.$inferSelect;
