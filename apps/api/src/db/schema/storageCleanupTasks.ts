import {
  index,
  integer,
  pgSchema,
  timestamp,
  uniqueIndex,
  uuid,
  varchar,
} from 'drizzle-orm/pg-core';
import { sql } from 'drizzle-orm';

const app = pgSchema('app');

/**
 * A durable outbox for object deletion. It intentionally has no user foreign
 * key: it must survive after the owning user row is gone.
 */
export const storageCleanupTasks = app.table(
  'storage_cleanup_tasks',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    objectKey: varchar('object_key', { length: 500 }).notNull(),
    attempts: integer('attempts').notNull().default(0),
    nextAttemptAt: timestamp('next_attempt_at', { withTimezone: true })
      .defaultNow()
      .notNull(),
    lastError: varchar('last_error', { length: 1000 }),
    createdAt: timestamp('created_at', { withTimezone: true })
      .defaultNow()
      .notNull(),
    completedAt: timestamp('completed_at', { withTimezone: true }),
  },
  (table) => ({
    objectKeyUnique: uniqueIndex('uq_storage_cleanup_tasks_object_key').on(
      table.objectKey,
    ),
    pendingIdx: index('idx_storage_cleanup_tasks_pending')
      .on(table.nextAttemptAt)
      .where(sql`${table.completedAt} IS NULL`),
  }),
);

export type StorageCleanupTask = typeof storageCleanupTasks.$inferSelect;
