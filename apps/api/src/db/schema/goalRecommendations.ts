import {
  pgSchema,
  uuid,
  date,
  jsonb,
  varchar,
  timestamp,
  index,
  uniqueIndex,
} from 'drizzle-orm/pg-core';
import { sql } from 'drizzle-orm';
import { users } from './users';
import type { GoalMetrics } from '../../goals/personalization/types';

const app = pgSchema('app');

export type RecommendationStatus =
  | 'pending'
  | 'accepted'
  | 'dismissed'
  | 'expired';

export interface RecommendationConfidence {
  level: 'low' | 'medium' | 'high';
  dataQualityScore: number;
  trackedDays: number;
  weightLogsCount: number;
  activityDays: number;
  workoutCount: number;
  sleepNights: number;
  adherenceStepsPct: number | null;
  weightTrendKgPerWeek: number | null;
}

export const goalRecommendations = app.table(
  'goal_recommendations',
  {
    id: uuid('id').primaryKey().defaultRandom(),

    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),

    status: varchar('status', { length: 20 })
      .$type<RecommendationStatus>()
      .default('pending')
      .notNull(),

    previousGoals: jsonb('previous_goals').$type<GoalMetrics>().notNull(),

    recommendedGoals: jsonb('recommended_goals')
      .$type<GoalMetrics>()
      .notNull(),

    analysisPeriodStart: date('analysis_period_start').notNull(),
    analysisPeriodEnd: date('analysis_period_end').notNull(),

    reasons: jsonb('reasons').$type<string[]>().default([]).notNull(),

    confidence: jsonb('confidence').$type<RecommendationConfidence>().notNull(),

    createdAt: timestamp('created_at', { withTimezone: true })
      .defaultNow()
      .notNull(),

    expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),

    acceptedAt: timestamp('accepted_at', { withTimezone: true }),

    dismissedAt: timestamp('dismissed_at', { withTimezone: true }),
  },
  (table) => ({
    userCreatedIdx: index('idx_goal_recommendations_user_created').on(
      table.userId,
      table.createdAt,
    ),
    pendingUnique: uniqueIndex('uq_goal_recommendations_pending')
      .on(table.userId)
      .where(sql`${table.status} = 'pending'`),
  }),
);

export type GoalRecommendation = typeof goalRecommendations.$inferSelect;
export type NewGoalRecommendation = typeof goalRecommendations.$inferInsert;
