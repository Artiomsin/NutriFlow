import {
  index,
  pgSchema,
  timestamp,
  uniqueIndex,
  uuid,
  varchar,
} from 'drizzle-orm/pg-core';
import { users } from './users';

const app = pgSchema('app');

/** An object-storage file that belongs to a user and must be deleted with them. */
export const userUploads = app.table(
  'user_uploads',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    objectKey: varchar('object_key', { length: 500 }).notNull(),
    contentType: varchar('content_type', { length: 100 }).notNull(),
    createdAt: timestamp('created_at', { withTimezone: true })
      .defaultNow()
      .notNull(),
  },
  (table) => ({
    objectKeyUnique: uniqueIndex('uq_user_uploads_object_key').on(
      table.objectKey,
    ),
    userIdIdx: index('idx_user_uploads_user_id').on(table.userId),
  }),
);

export type UserUpload = typeof userUploads.$inferSelect;
