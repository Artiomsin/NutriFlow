import { Injectable, NotFoundException } from '@nestjs/common';
import { db } from '../../db/db';
import { userGoals } from '../../db/schema/userGoals';
import { goalRecommendations } from '../../db/schema/goalRecommendations';
import { goalHistory } from '../../db/schema/goalHistory';
import type { GoalMetrics } from './types';
import { generateRecommendation } from './recommendation';
import { DataCollectionService } from './data-collection.service';
import { recordGoalHistory } from '../goals-history';
import { eq, and, lt, desc } from 'drizzle-orm';
import { invalidateAnalyticsCache } from '../../redis';

export const PERSONALIZATION_INTERVAL_DAYS = 14;
export const RECOMMENDATION_TTL_DAYS = 7;

export type PersonalizeResult =
  | { status: 'created'; recommendation: unknown }
  | { status: 'pending_exists'; recommendation: unknown }
  | { status: 'not_due'; lastEvaluationAt: Date }
  | { status: 'insufficient_data' };

@Injectable()
export class GoalPersonalizationService {
  constructor(private readonly dataCollection: DataCollectionService) {}

  async personalize(userId: string): Promise<PersonalizeResult> {
    await this.expireOverduePending(userId);

    const pending = await this.findPending(userId);
    if (pending) {
      return { status: 'pending_exists', recommendation: pending };
    }

    const lastEvaluationAt = await this.getLastEvaluationAt(userId);
    const now = new Date();
    const dueMs = PERSONALIZATION_INTERVAL_DAYS * 24 * 60 * 60 * 1000;
    if (now.getTime() - lastEvaluationAt.getTime() < dueMs) {
      return { status: 'not_due', lastEvaluationAt };
    }

    const collected = await this.dataCollection.collect(userId);
    const recommendation = generateRecommendation(collected.input);

    if (!recommendation) {
      return { status: 'insufficient_data' };
    }

    const [row] = await db
      .insert(goalRecommendations)
      .values({
        userId,
        status: 'pending',
        previousGoals: recommendation.previousGoals,
        recommendedGoals: recommendation.recommendedGoals,
        analysisPeriodStart: recommendation.analysisPeriodStart,
        analysisPeriodEnd: recommendation.analysisPeriodEnd,
        reasons: recommendation.reasons,
        confidence: recommendation.confidence,
        expiresAt: new Date(
          now.getTime() + RECOMMENDATION_TTL_DAYS * 24 * 60 * 60 * 1000,
        ),
      })
      .returning();

    return { status: 'created', recommendation: row };
  }

  async getPersonalizationState(userId: string) {
    await this.expireOverduePending(userId);
    const pending = await this.findPending(userId);
    return {
      pending: pending ?? null,
      personalizationDue: this.isDue(await this.getLastEvaluationAt(userId)),
    };
  }

  async acceptRecommendation(userId: string, recommendationId: string) {
    const rec = await db
      .select()
      .from(goalRecommendations)
      .where(
        and(
          eq(goalRecommendations.id, recommendationId),
          eq(goalRecommendations.userId, userId),
        ),
      )
      .limit(1);

    const recRow = rec[0];
    if (!recRow) {
      throw new NotFoundException('Recommendation not found');
    }
    if (recRow.status !== 'pending') {
      throw new NotFoundException('Recommendation is not pending');
    }

    const previous = recRow.previousGoals;
    const next = recRow.recommendedGoals;

    const existing = await db
      .select()
      .from(userGoals)
      .where(eq(userGoals.userId, userId))
      .limit(1);

    if (existing[0]) {
      await db
        .update(userGoals)
        .set({ ...this.toGoalFields(next), source: 'personalized' })
        .where(eq(userGoals.userId, userId));
    } else {
      await db
        .insert(userGoals)
        .values({ userId, ...this.toGoalFields(next), source: 'personalized' });
    }

    await recordGoalHistory(
      userId,
      previous,
      next,
      'personalized',
      'recommendation_accepted',
    );

    await db
      .update(goalRecommendations)
      .set({ status: 'accepted', acceptedAt: new Date() })
      .where(eq(goalRecommendations.id, recommendationId));

    await invalidateAnalyticsCache(userId);

    return next;
  }

  async dismissRecommendation(userId: string, recommendationId: string) {
    const rec = await db
      .select()
      .from(goalRecommendations)
      .where(
        and(
          eq(goalRecommendations.id, recommendationId),
          eq(goalRecommendations.userId, userId),
        ),
      )
      .limit(1);

    const recRow = rec[0];
    if (!recRow) {
      throw new NotFoundException('Recommendation not found');
    }
    if (recRow.status !== 'pending') {
      throw new NotFoundException('Recommendation is not pending');
    }

    await db
      .update(goalRecommendations)
      .set({ status: 'dismissed', dismissedAt: new Date() })
      .where(eq(goalRecommendations.id, recommendationId));

    return { dismissed: true };
  }

  async getGoalHistory(userId: string) {
    return db
      .select()
      .from(goalHistory)
      .where(eq(goalHistory.userId, userId))
      .orderBy(desc(goalHistory.createdAt))
      .limit(200);
  }

  private async findPending(userId: string) {
    const rows = await db
      .select()
      .from(goalRecommendations)
      .where(
        and(
          eq(goalRecommendations.userId, userId),
          eq(goalRecommendations.status, 'pending'),
        ),
      )
      .orderBy(desc(goalRecommendations.createdAt))
      .limit(1);
    return rows[0] ?? null;
  }

  private async getLastEvaluationAt(userId: string): Promise<Date> {
    const [goalsRow] = await db
      .select()
      .from(userGoals)
      .where(eq(userGoals.userId, userId))
      .limit(1);

    const [lastRec] = await db
      .select()
      .from(goalRecommendations)
      .where(eq(goalRecommendations.userId, userId))
      .orderBy(desc(goalRecommendations.createdAt))
      .limit(1);

    if (lastRec?.acceptedAt) return lastRec.acceptedAt;
    if (lastRec?.dismissedAt) return lastRec.dismissedAt;
    if (lastRec) return lastRec.createdAt;

    return goalsRow?.createdAt ?? new Date();
  }

  private isDue(lastEvaluationAt: Date): boolean {
    const now = new Date();
    const dueMs = PERSONALIZATION_INTERVAL_DAYS * 24 * 60 * 60 * 1000;
    return now.getTime() - lastEvaluationAt.getTime() >= dueMs;
  }

  private async expireOverduePending(userId: string) {
    await db
      .update(goalRecommendations)
      .set({ status: 'expired' })
      .where(
        and(
          eq(goalRecommendations.userId, userId),
          eq(goalRecommendations.status, 'pending'),
          lt(goalRecommendations.expiresAt, new Date()),
        ),
      );
  }

  private toGoalFields(metrics: GoalMetrics) {
    return {
      dailyCaloriesGoal: metrics.dailyCaloriesGoal,
      dailyProteinGoal: metrics.dailyProteinGoal,
      dailyFatGoal: metrics.dailyFatGoal,
      dailyCarbsGoal: metrics.dailyCarbsGoal,
      dailyWaterGoal: metrics.dailyWaterGoal,
      dailyStepsGoal: metrics.dailyStepsGoal,
      dailyActiveCaloriesGoal: metrics.dailyActiveCaloriesGoal,
      weeklyWorkoutsGoal: metrics.weeklyWorkoutsGoal,
      weeklyWorkoutMinutesGoal: metrics.weeklyWorkoutMinutesGoal,
      nightlySleepMinMinutes: metrics.nightlySleepMinMinutes,
      nightlySleepMaxMinutes: metrics.nightlySleepMaxMinutes,
    };
  }
}
