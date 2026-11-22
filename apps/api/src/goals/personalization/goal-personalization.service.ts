import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import type { Db } from '../../db/db';
import { DB } from '../../db/db.module';
import { userGoals } from '../../db/schema/userGoals';
import { goalRecommendations } from '../../db/schema/goalRecommendations';
import type { GoalMetrics } from './types';
import {
  recordGoalHistory,
  rowToGoalMetrics,
  EMPTY_GOALS_METRICS,
} from '../goals-history';
import { eq, and, lt, desc, isNull, sql } from 'drizzle-orm';
import { GoalsProgressService } from '../goals-progress.service';

export const PERSONALIZATION_INTERVAL_DAYS = 7;
export const RECOMMENDATION_TTL_DAYS = 7;
export const ADJUSTMENT_COOLDOWN_DAYS = 14;

export type PersonalizeResult =
  | { status: 'created'; recommendation: unknown }
  | { status: 'pending_exists'; recommendation: unknown }
  | { status: 'not_due'; lastEvaluationAt: Date; nextAvailableAt: Date }
  | { status: 'insufficient_data' }
  | { status: 'no_change'; progress?: unknown }
  | { status: 'collect_data'; progress?: unknown };

type ProgressAction =
  | 'none'
  | 'collect_data'
  | 'adjust_plan'
  | 'ease_plan'
  | 'slow_down';

@Injectable()
export class GoalPersonalizationService {
  constructor(
    @Inject(DB) private readonly db: Db,
    private readonly progressService: GoalsProgressService,
  ) {}

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
      return {
        status: 'not_due',
        lastEvaluationAt,
        nextAvailableAt: this.nextAvailableAt(lastEvaluationAt),
      };
    }

    const progress = await this.progressService.getWeeklyProgress(userId, 14);
    const recentEvaluations = await this.getRecentEvaluations(userId, 5);
    const confidence = this.mapConfidence(progress);
    const action = (progress.recommendation.action ?? 'none') as ProgressAction;

    const createEvaluationMarker = async (
      status: 'no_change' | 'collect_data' | 'insufficient_data',
      effectiveAction: ProgressAction = action,
      extraReasons: string[] = [],
    ) => {
      const [row] = await this.db
        .insert(goalRecommendations)
        .values({
          userId,
          status,
          previousGoals: progress.appliedGoals,
          recommendedGoals:
            progress.recommendation.suggestedAdjustment?.metrics ??
            progress.appliedGoals,
          analysisPeriodStart: progress.period.start,
          analysisPeriodEnd: progress.period.end,
          reasons: [
            `status:${progress.status}`,
            `reason:${progress.reason}`,
            `action:${effectiveAction}`,
            progress.recommendation.text,
            ...extraReasons,
          ],
          confidence,
          expiresAt: new Date(
            now.getTime() + RECOMMENDATION_TTL_DAYS * 24 * 60 * 60 * 1000,
          ),
        })
        .returning();
      return row;
    };

    // 1) Insufficient data or explicit collect_data: never change plan.
    if (progress.status === 'insufficient_data' || action === 'collect_data') {
      const markerStatus =
        progress.status === 'insufficient_data'
          ? 'insufficient_data'
          : 'collect_data';
      await createEvaluationMarker(markerStatus, 'collect_data');
      return { status: markerStatus, progress };
    }

    // 2) Low confidence: collect data / no change, do not apply plan changes.
    if (confidence.level === 'low') {
      await createEvaluationMarker('collect_data', 'collect_data', [
        'guard:low_confidence',
      ]);
      return { status: 'collect_data', progress };
    }

    const adjustment = progress.recommendation.suggestedAdjustment;
    if (
      !adjustment ||
      action === 'none' ||
      progress.recommendation.nothingToChange ||
      adjustment.diff.length === 0
    ) {
      await createEvaluationMarker('no_change', 'none');
      return { status: 'no_change', progress };
    }

    // 3) Safety priority: slow_down is allowed even during normal cooldown.
    const cooldownActive = await this.isAdjustmentCooldownActive(userId, now);
    if (cooldownActive && action !== 'slow_down') {
      await createEvaluationMarker('no_change', 'none', [
        'guard:adjustment_cooldown_active',
      ]);
      return { status: 'no_change', progress };
    }

    // 4) Hysteresis: entering off_track from on_track/slightly_off requires stronger evidence.
    if (progress.status === 'off_track') {
      const prevStatus = this.latestEvaluationStatus(recentEvaluations);
      const strongEvidence =
        confidence.level === 'high' ||
        (confidence.level === 'medium' &&
          (progress.metrics.loggedDaysCount >= 7 ||
            progress.metrics.weighInsCount >= 4));
      if (
        (prevStatus === 'on_track' ||
          prevStatus === 'slightly_off' ||
          prevStatus == null) &&
        !strongEvidence
      ) {
        await createEvaluationMarker('collect_data', 'collect_data', [
          'guard:off_track_hysteresis_needs_stronger_evidence',
        ]);
        return { status: 'collect_data', progress };
      }
    }

    // 5) Slightly off: require 2 of 3 same action+reason signals (including current).
    // Hysteresis: if previous evaluation was off_track, allow easier exit to slightly_off.
    if (progress.status === 'slightly_off') {
      const prevStatus = this.latestEvaluationStatus(recentEvaluations);
      const sameSignalCount = this.countSameSignals(
        recentEvaluations.slice(0, 2),
        action,
        progress.reason,
      ); // last 2 prior + current = 3
      const hasTwoOfThree = sameSignalCount + 1 >= 2;
      const easierExitFromOffTrack = prevStatus === 'off_track'; // confidence already medium/high here
      if (!hasTwoOfThree && !easierExitFromOffTrack) {
        await createEvaluationMarker('no_change', 'none', [
          'guard:slightly_off_requires_2_of_3',
        ]);
        return { status: 'no_change', progress };
      }
    }

    // 6) Priority guardrail: if adherence is poor, prefer ease_plan over adjust_plan.
    let effectiveAction: ProgressAction = action;
    let effectiveAdjustment = adjustment;
    if (
      effectiveAction === 'adjust_plan' &&
      (progress.metrics.calorieAdherence ?? 1) < 0.5
    ) {
      // Do not create an aggressive adjustment on poor adherence.
      effectiveAction = 'ease_plan';
      const eased = progress.recommendation.suggestedAdjustment;
      // If no safe adjustment available, collect data instead of guessing.
      if (!eased || eased.diff.length === 0) {
        await createEvaluationMarker('collect_data', 'collect_data', [
          'guard:poor_adherence_no_safe_adjustment',
        ]);
        return { status: 'collect_data', progress };
      }
      effectiveAdjustment = eased;
    }

    try {
      const [created] = await this.db
        .insert(goalRecommendations)
        .values({
          userId,
          status: 'pending',
          previousGoals: progress.appliedGoals,
          recommendedGoals: effectiveAdjustment.metrics,
          analysisPeriodStart: progress.period.start,
          analysisPeriodEnd: progress.period.end,
          reasons: [
            `status:${progress.status}`,
            `reason:${progress.reason}`,
            `action:${effectiveAction}`,
            progress.recommendation.text,
            ...(effectiveAction !== action
              ? [`guard:action_adjusted_from:${action}`]
              : []),
          ],
          confidence,
          expiresAt: new Date(
            now.getTime() + RECOMMENDATION_TTL_DAYS * 24 * 60 * 60 * 1000,
          ),
        })
        .returning();
      if (!created) throw new Error('Failed to create recommendation');
      return { status: 'created', recommendation: created };
    } catch (error) {
      if (!this.isUniqueViolation(error)) throw error;
      const existing = await this.findPending(userId);
      if (existing)
        return { status: 'pending_exists', recommendation: existing };
      throw error;
    }
  }

  private async getRecentEvaluations(userId: string, limit: number) {
    return this.db
      .select({
        status: goalRecommendations.status,
        reasons: goalRecommendations.reasons,
        createdAt: goalRecommendations.createdAt,
        acceptedAt: goalRecommendations.acceptedAt,
      })
      .from(goalRecommendations)
      .where(eq(goalRecommendations.userId, userId))
      .orderBy(desc(goalRecommendations.createdAt))
      .limit(limit);
  }

  private latestEvaluationStatus(
    evaluations: Array<{ reasons: unknown; status: string }>,
  ): string | null {
    for (const ev of evaluations) {
      const reasons = Array.isArray(ev.reasons) ? (ev.reasons as string[]) : [];
      const statusTag = reasons.find((r) => r.startsWith('status:'));
      if (statusTag) return statusTag.slice('status:'.length);
      // fallback: map marker status
      if (ev.status === 'no_change') return 'on_track';
    }
    return null;
  }

  private countSameSignals(
    evaluations: Array<{ reasons: unknown }>,
    action: ProgressAction,
    reason: string,
  ): number {
    let count = 0;
    for (const ev of evaluations) {
      const reasons = Array.isArray(ev.reasons) ? (ev.reasons as string[]) : [];
      const hasAction = reasons.includes(`action:${action}`);
      const hasReason = reasons.includes(`reason:${reason}`);
      if (hasAction && hasReason) count++;
    }
    return count;
  }

  private async isAdjustmentCooldownActive(
    userId: string,
    now: Date,
  ): Promise<boolean> {
    const cooldownMs = ADJUSTMENT_COOLDOWN_DAYS * 24 * 60 * 60 * 1000;
    const cutoff = new Date(now.getTime() - cooldownMs);

    // Last accepted actionable recommendation
    const acceptedRows = await this.db
      .select({
        acceptedAt: goalRecommendations.acceptedAt,
        reasons: goalRecommendations.reasons,
        status: goalRecommendations.status,
      })
      .from(goalRecommendations)
      .where(
        and(
          eq(goalRecommendations.userId, userId),
          eq(goalRecommendations.status, 'accepted'),
        ),
      )
      .orderBy(desc(goalRecommendations.acceptedAt))
      .limit(5);

    const lastAccepted = acceptedRows.find(
      (r) => r.acceptedAt && r.acceptedAt >= cutoff,
    );
    if (lastAccepted) return true;

    // Check recent goal versions for progress_* reasons (excluding progress_none/collect_data)
    const recentGoals = await this.db
      .select({
        changeReason: userGoals.changeReason,
        startedAt: userGoals.startedAt,
      })
      .from(userGoals)
      .where(eq(userGoals.userId, userId))
      .orderBy(desc(userGoals.startedAt))
      .limit(10);
    const appliedProgress = recentGoals.find(
      (g) =>
        g.startedAt >= cutoff &&
        typeof g.changeReason === 'string' &&
        g.changeReason.startsWith('progress_') &&
        g.changeReason !== 'progress_none' &&
        g.changeReason !== 'progress_collect_data',
    );
    if (appliedProgress) return true;

    return false;
  }

  private mapConfidence(
    progress: Awaited<ReturnType<GoalsProgressService['getWeeklyProgress']>>,
  ) {
    const m = progress.metrics;
    const trackedDays = Math.max(
      m.loggedDaysCount,
      m.weighInsCount,
      m.activityDaysCount,
      m.workoutDaysCount,
      m.sleepNightsCount,
    );
    const dataQualityScore = Math.max(
      0,
      Math.min(
        1,
        ((m.weighInsCount >= 3 ? 1 : m.weighInsCount / 3) +
          (m.loggedDaysCount >= 4 ? 1 : m.loggedDaysCount / 4) +
          (m.activityDaysCount >= 3 ? 1 : m.activityDaysCount / 3) +
          (m.sleepNightsCount >= 3 ? 1 : m.sleepNightsCount / 3) +
          (m.workoutDaysCount >= 1 ? 1 : 0)) /
          5,
      ),
    );
    const level: 'low' | 'medium' | 'high' =
      progress.confidence === 'high' ||
      progress.confidence === 'medium' ||
      progress.confidence === 'low'
        ? progress.confidence
        : dataQualityScore >= 0.75
          ? 'high'
          : dataQualityScore >= 0.45
            ? 'medium'
            : 'low';
    return {
      level,
      dataQualityScore,
      trackedDays,
      weightLogsCount: m.weighInsCount,
      activityDays: m.activityDaysCount,
      workoutCount: m.workoutDaysCount,
      sleepNights: m.sleepNightsCount,
      adherenceStepsPct: null,
      weightTrendKgPerWeek: m.actualRateKgPerWeek,
    };
  }

  async getPersonalizationState(userId: string) {
    await this.expireOverduePending(userId);
    const pending = await this.findPending(userId);
    const lastEvaluationAt = await this.getLastEvaluationAt(userId);
    const personalizationDue = this.isDue(lastEvaluationAt);
    return {
      pending: pending ?? null,
      personalizationDue,
      nextAvailableAt: personalizationDue
        ? null
        : this.nextAvailableAt(lastEvaluationAt),
    };
  }

  private isUniqueViolation(error: unknown): boolean {
    return (
      typeof error === 'object' &&
      error !== null &&
      'code' in error &&
      (error as { code?: unknown }).code === '23505'
    );
  }

  async acceptRecommendation(userId: string, recommendationId: string) {
    return this.db.transaction(async (tx) => {
      // Serialize goal writes for this user, exactly like GoalsService does.
      await tx.execute(sql`SELECT pg_advisory_xact_lock(hashtext(${userId}))`);

      // Claim the pending recommendation first. The status predicate prevents
      // concurrent requests from applying the same recommendation twice.
      const [recRow] = await tx
        .update(goalRecommendations)
        .set({ status: 'accepted', acceptedAt: new Date() })
        .where(
          and(
            eq(goalRecommendations.id, recommendationId),
            eq(goalRecommendations.userId, userId),
            eq(goalRecommendations.status, 'pending'),
          ),
        )
        .returning();

      if (!recRow) {
        throw new NotFoundException('Recommendation is not pending');
      }

      const next = recRow.recommendedGoals;
      const now = new Date();

      // Read only the version that is active right now. Historical versions
      // must stay untouched so past days keep showing the goal they had.
      const [existing] = await tx
        .select()
        .from(userGoals)
        .where(and(eq(userGoals.userId, userId), isNull(userGoals.endedAt)))
        .orderBy(desc(userGoals.startedAt))
        .limit(1);

      if (existing) {
        // Close the current version instead of overwriting it.
        await tx
          .update(userGoals)
          .set({ endedAt: now, updatedAt: now })
          .where(
            and(
              eq(userGoals.id, existing.id),
              eq(userGoals.userId, userId),
              isNull(userGoals.endedAt),
            ),
          );
      }

      const [created] = await tx
        .insert(userGoals)
        .values({
          userId,
          ...this.toGoalFields(next),
          mode: 'auto',
          source: 'personalized',
          changeReason: 'recommendation_accepted',
          suggestedGoals: null,
          suggestionReason: null,
          suggestedAt: null,
          suggestionBasis: null,
          appliedBasis: {
            fromRecommendation: recRow.id,
            analysisPeriodStart: recRow.analysisPeriodStart,
            analysisPeriodEnd: recRow.analysisPeriodEnd,
          },
          startedAt: now,
          endedAt: null,
          createdAt: now,
          updatedAt: now,
        })
        .returning();

      await recordGoalHistory(
        userId,
        existing ? rowToGoalMetrics(existing) : { ...EMPTY_GOALS_METRICS },
        rowToGoalMetrics(created),
        'personalized',
        'recommendation_accepted',
        tx,
      );

      return next;
    });
  }

  async dismissRecommendation(userId: string, recommendationId: string) {
    const rec = await this.db
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

    await this.db
      .update(goalRecommendations)
      .set({ status: 'dismissed', dismissedAt: new Date() })
      .where(eq(goalRecommendations.id, recommendationId));

    return { dismissed: true };
  }

  private async findPending(userId: string) {
    const rows = await this.db
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
    const [goalsRow] = await this.db
      .select()
      .from(userGoals)
      .where(and(eq(userGoals.userId, userId), isNull(userGoals.endedAt)))
      .orderBy(desc(userGoals.startedAt))
      .limit(1);

    const [lastRec] = await this.db
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

  private nextAvailableAt(lastEvaluationAt: Date): Date {
    return new Date(
      lastEvaluationAt.getTime() +
        PERSONALIZATION_INTERVAL_DAYS * 24 * 60 * 60 * 1000,
    );
  }

  private async expireOverduePending(userId: string) {
    await this.db
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
