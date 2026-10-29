import {
  pgSchema,
  uuid,
  varchar,
  numeric,
  timestamp,
  index,
} from 'drizzle-orm/pg-core';
import { users } from './users';
import type { GoalSource } from './userGoals';

const app = pgSchema('app');

export type GoalTypeValue = 'nutrition' | 'activity' | 'workout' | 'sleep';

export const goalHistory = app.table(
  'goal_history',
  {
    id: uuid('id').primaryKey().defaultRandom(),

    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),

    goalType: varchar('goal_type', { length: 20 })
      .$type<GoalTypeValue>()
      .notNull(),

    metric: varchar('metric', { length: 40 }).notNull(),

    oldValue: numeric('old_value', {
      precision: 10,
      scale: 1,
      mode: 'number',
    }),

    newValue: numeric('new_value', {
      precision: 10,
      scale: 1,
      mode: 'number',
    }),

    source: varchar('source', { length: 20 }).$type<GoalSource>().notNull(),

    reason: varchar('reason', { length: 100 }),

    createdAt: timestamp('created_at', { withTimezone: true })
      .defaultNow()
      .notNull(),

    // `createdAt` marks the start of an edit session; `updatedAt` marks its
    // latest change and drives the coalescing window.
    updatedAt: timestamp('updated_at', { withTimezone: true })
      .defaultNow()
      .$onUpdate(() => new Date())
      .notNull(),
  },
  (table) => ({
    userCreatedIdx: index('idx_goal_history_user_created').on(
      table.userId,
      table.createdAt,
    ),
    userUpdatedIdx: index('idx_goal_history_user_updated').on(
      table.userId,
      table.updatedAt,
    ),
  }),
);

export type GoalHistory = typeof goalHistory.$inferSelect;
export type NewGoalHistory = typeof goalHistory.$inferInsert;
