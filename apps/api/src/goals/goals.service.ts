import {
  Inject,
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import type { Db } from '../db/db';
import { DB } from '../db/db.module';
import { userGoals } from '../db/schema/userGoals';
import { goalRecommendations } from '../db/schema/goalRecommendations';
import { userProfiles } from '../db/schema/userProfiles';
import { and, desc, eq, gt, isNull, lt, or, sql } from 'drizzle-orm';
import { roundNutrition } from '../common/nutrition/precision';
import { zonedDayRange } from '../common/time/user-date';
import type { GoalsHistoryQueryDto, UpdateGoalsDto } from './goals.schema';
import type { GoalMetrics } from './personalization/types';
import {
  recordGoalHistory,
  rowToGoalMetrics,
  EMPTY_GOALS_METRICS,
} from './goals-history';
import { diffGoalMetrics } from './goal-versions';
import type { GoalHistoryPage, GoalVersionEntry } from './goal-versions';

type DatabaseExecutor = Pick<Db, 'select' | 'insert' | 'update' | 'execute'>;

type GoalSource = 'initial' | 'user' | 'personalized';

@Injectable()
export class GoalsService {
  constructor(@Inject(DB) private readonly db: Db) {}

  /**
   * Without date, returns the active goals.
   *
   * With date, returns the goal version that was effective during that
   * calendar day. Date boundaries are interpreted in `tz` (IANA name), falling
   * back to UTC when it is missing or invalid.
   */
  async findByUserId(userId: string, date?: string, tz?: string) {
    const conditions = [eq(userGoals.userId, userId)];

    if (date !== undefined) {
      const { start, end } = this.getDayRange(date, tz);

      conditions.push(
        lt(userGoals.startedAt, end),
        or(isNull(userGoals.endedAt), gt(userGoals.endedAt, start))!,
      );
    } else {
      conditions.push(isNull(userGoals.endedAt));
    }

    const [goals] = await this.db
      .select()
      .from(userGoals)
      .where(and(...conditions))
      .orderBy(desc(userGoals.startedAt))
      .limit(1);

    if (!goals) {
      throw new NotFoundException('Goals not found');
    }

    return goals;
  }

  /**
   * Goal versions newest first, each with the diff against the version it
   * replaced.
   *
   * Without `date` the response is paginated with `limit`/`cursor`. With
   * `date` it returns every version in effect during that day in `tz`, which
   * is what the day detail sheet renders. There is no coalescing: two edits
   * minutes apart are two versions and therefore two entries.
   */
  async getHistory(
    userId: string,
    query: GoalsHistoryQueryDto,
  ): Promise<GoalHistoryPage> {
    if (query.date !== undefined) {
      return this.getHistoryForDay(userId, query.date, query.tz);
    }

    return this.getHistoryPage(userId, query.limit, query.cursor);
  }

  private async getHistoryForDay(
    userId: string,
    date: string,
    tz?: string,
  ): Promise<GoalHistoryPage> {
    const { start, end } = this.getDayRange(date, tz);

    const rows = await this.db
      .select()
      .from(userGoals)
      .where(
        and(
          eq(userGoals.userId, userId),
          lt(userGoals.startedAt, end),
          or(isNull(userGoals.endedAt), gt(userGoals.endedAt, start))!,
        ),
      )
      .orderBy(desc(userGoals.startedAt), desc(userGoals.id));

    if (rows.length === 0) {
      return { items: [], nextCursor: null };
    }

    // The oldest version in the day still needs the version it replaced to
    // show a diff, and that predecessor may have started before the day.
    const oldest = rows[rows.length - 1]!;
    const [previous] = await this.db
      .select()
      .from(userGoals)
      .where(
        and(
          eq(userGoals.userId, userId),
          lt(userGoals.startedAt, oldest.startedAt),
        ),
      )
      .orderBy(desc(userGoals.startedAt))
      .limit(1);

    return {
      items: this.buildVersionEntries(
        previous ? [...rows, previous] : rows,
        rows.length,
      ),
      nextCursor: null,
    };
  }

  private async getHistoryPage(
    userId: string,
    limit: number,
    cursor?: string,
  ): Promise<GoalHistoryPage> {
    const conditions = [eq(userGoals.userId, userId)];

    if (cursor !== undefined) {
      const [cursorRow] = await this.db
        .select({ startedAt: userGoals.startedAt })
        .from(userGoals)
        .where(and(eq(userGoals.userId, userId), eq(userGoals.id, cursor)))
        .limit(1);

      if (!cursorRow) {
        throw new BadRequestException('Invalid history cursor.');
      }

      // Composite cursor: versions can share a millisecond, so the id breaks
      // the tie without skipping or repeating a version.
      conditions.push(
        or(
          lt(userGoals.startedAt, cursorRow.startedAt),
          and(
            eq(userGoals.startedAt, cursorRow.startedAt),
            lt(userGoals.id, cursor),
          ),
        )!,
      );
    }

    // One extra row is the predecessor of the oldest visible entry, so every
    // returned entry can be diffed inside this page.
    const rows = await this.db
      .select()
      .from(userGoals)
      .where(and(...conditions))
      .orderBy(desc(userGoals.startedAt), desc(userGoals.id))
      .limit(limit + 1);

    const count = Math.min(rows.length, limit);

    return {
      items: this.buildVersionEntries(rows, count),
      nextCursor: rows.length > limit && count > 0 ? rows[count - 1]!.id : null,
    };
  }

  private buildVersionEntries(
    rows: (typeof userGoals.$inferSelect)[],
    count: number,
  ): GoalVersionEntry[] {
    return rows.slice(0, count).map((row, index) => {
      const previous = rows[index + 1];
      const goal = rowToGoalMetrics(row);

      return {
        id: row.id,
        startedAt: row.startedAt.toISOString(),
        endedAt: row.endedAt ? row.endedAt.toISOString() : null,
        source: row.source ?? 'initial',
        reason: row.changeReason ?? null,
        changes: diffGoalMetrics(
          previous ? rowToGoalMetrics(previous) : null,
          goal,
        ),
        goal,
      };
    });
  }

  async update(userId: string, data: UpdateGoalsDto) {
    return this.db.transaction(async (tx) => {
      await this.acquireUserLock(userId, tx);

      const existing = await this.findByUserIdSafe(userId, tx);

      const nextMetrics: GoalMetrics = {
        ...rowToGoalMetrics(existing),
        ...data,
      };

      return this.replaceCurrentGoals(
        userId,
        existing,
        nextMetrics,
        'user',
        'user_edit',
        tx,
      );
    });
  }

  /**
   * If called without an executor, creates its own transaction.
   *
   * If an executor is supplied, it must be the transaction executor of an
   * already-open transaction. The advisory lock is acquired in that
   * transaction and therefore remains held until it commits or rolls back.
   */
  async calculate(
    userId: string,
    executor?: DatabaseExecutor,
    forceAutomatic = false,
  ) {
    if (executor) {
      await this.acquireUserLock(userId, executor);

      return this.calculateWithExecutor(userId, executor, forceAutomatic);
    }

    return this.db.transaction(async (tx) => {
      await this.acquireUserLock(userId, tx);

      return this.calculateWithExecutor(userId, tx, forceAutomatic);
    });
  }

  async resetToAutomatic(userId: string) {
    return this.calculate(userId, undefined, true);
  }

  private async calculateWithExecutor(
    userId: string,
    executor: DatabaseExecutor,
    forceAutomatic: boolean,
  ) {
    const [profile] = await executor
      .select()
      .from(userProfiles)
      .where(eq(userProfiles.userId, userId))
      .limit(1);

    if (!profile) {
      throw new NotFoundException('Profile not found');
    }

    const { weight, height, age, gender, goal, activityLevel } = profile;

    if (!weight || !height || !age || !gender || !goal || !activityLevel) {
      throw new BadRequestException(
        'Not enough profile data to calculate goals. Provide weight, height, age, gender, goal and activityLevel.',
      );
    }

    // Nutrition
    const bmr = this.calculateBMR(weight, height, age, gender);
    const tdee = this.calculateTDEE(bmr, activityLevel);
    const goalCalories = this.adjustForGoal(tdee, goal);

    const protein = this.calculateProtein(weight, goal);
    const fat = (goalCalories * 0.25) / 9;

    const proteinCals = protein * 4;
    const fatCals = fat * 9;
    const carbs = (goalCalories - proteinCals - fatCals) / 4;

    const waterMultipliers: Record<string, number> = {
      low: 30,
      medium: 35,
      high: 40,
    };

    const water = weight * (waterMultipliers[activityLevel] ?? 35);

    // Activity / workout / sleep
    const activityGoals = this.calculateActivityGoals(activityLevel);
    const workoutGoals = this.calculateWorkoutGoals(activityLevel);
    const sleepGoals = this.calculateSleepGoals();

    const calculated: GoalMetrics = {
      dailyCaloriesGoal: roundNutrition(goalCalories),
      dailyProteinGoal: roundNutrition(protein),
      dailyFatGoal: roundNutrition(fat),
      dailyCarbsGoal: roundNutrition(carbs),
      dailyWaterGoal: Math.round(water),

      dailyStepsGoal: activityGoals.steps,
      dailyActiveCaloriesGoal: activityGoals.activeCalories,

      weeklyWorkoutsGoal: workoutGoals.workouts,
      weeklyWorkoutMinutesGoal: workoutGoals.minutes,

      nightlySleepMinMinutes: sleepGoals.minMinutes,
      nightlySleepMaxMinutes: sleepGoals.maxMinutes,
    };

    const existing = await this.findByUserIdSafe(userId, executor);

    if (existing?.source === 'user' && !forceAutomatic) {
      const currentMetrics = rowToGoalMetrics(existing);
      const merged: GoalMetrics = {
        dailyCaloriesGoal:
          existing.dailyCaloriesGoal ?? calculated.dailyCaloriesGoal,
        dailyProteinGoal:
          existing.dailyProteinGoal ?? calculated.dailyProteinGoal,
        dailyFatGoal: existing.dailyFatGoal ?? calculated.dailyFatGoal,
        dailyCarbsGoal: existing.dailyCarbsGoal ?? calculated.dailyCarbsGoal,
        dailyWaterGoal: existing.dailyWaterGoal ?? calculated.dailyWaterGoal,
        dailyStepsGoal: existing.dailyStepsGoal ?? calculated.dailyStepsGoal,
        dailyActiveCaloriesGoal:
          existing.dailyActiveCaloriesGoal ??
          calculated.dailyActiveCaloriesGoal,
        weeklyWorkoutsGoal:
          existing.weeklyWorkoutsGoal ?? calculated.weeklyWorkoutsGoal,
        weeklyWorkoutMinutesGoal:
          existing.weeklyWorkoutMinutesGoal ??
          calculated.weeklyWorkoutMinutesGoal,
        nightlySleepMinMinutes:
          existing.nightlySleepMinMinutes ?? calculated.nightlySleepMinMinutes,
        nightlySleepMaxMinutes:
          existing.nightlySleepMaxMinutes ?? calculated.nightlySleepMaxMinutes,
      };

      if (this.sameGoalMetrics(currentMetrics, merged)) {
        return existing;
      }

      return this.replaceCurrentGoals(
        userId,
        existing,
        merged,
        'user',
        'profile_recalculation',
        executor,
      );
    }

    if (existing?.source === 'personalized' && !forceAutomatic) {
      const personalized = await this.applyLatestRecommendationAdjustment(
        userId,
        calculated,
        executor,
      );

      if (this.sameGoalMetrics(rowToGoalMetrics(existing), personalized)) {
        return existing;
      }

      return this.replaceCurrentGoals(
        userId,
        existing,
        personalized,
        'personalized',
        'personalized_profile_recalculation',
        executor,
      );
    }

    const reason = !existing
      ? 'initial_calculation'
      : forceAutomatic
        ? 'manual_reset_to_automatic'
        : 'profile_recalculation';

    return this.replaceCurrentGoals(
      userId,
      existing,
      calculated,
      'initial',
      reason,
      executor,
    );
  }

  /**
   * Closes the current version and inserts a new snapshot.
   * This method must run inside a transaction while holding the user lock.
   */
  private async replaceCurrentGoals(
    userId: string,
    existing: typeof userGoals.$inferSelect | undefined,
    nextMetrics: GoalMetrics,
    source: GoalSource,
    reason: string,
    executor: DatabaseExecutor,
  ) {
    const previousMetrics = rowToGoalMetrics(existing);

    if (
      existing &&
      existing.source === source &&
      this.sameGoalMetrics(previousMetrics, nextMetrics)
    ) {
      return existing;
    }

    const now = new Date();

    if (existing) {
      await executor
        .update(userGoals)
        .set({
          endedAt: now,
          updatedAt: now,
        })
        .where(
          and(
            eq(userGoals.id, existing.id),
            eq(userGoals.userId, userId),
            isNull(userGoals.endedAt),
          ),
        );
    }

    const [created] = await executor
      .insert(userGoals)
      .values({
        userId,
        ...nextMetrics,
        source,
        changeReason: reason,
        startedAt: now,
        endedAt: null,
        createdAt: now,
        updatedAt: now,
      })
      .returning();

    await recordGoalHistory(
      userId,
      previousMetrics,
      rowToGoalMetrics(created),
      source,
      reason,
      executor,
    );

    return created;
  }

  private sameGoalMetrics(first: GoalMetrics, second: GoalMetrics): boolean {
    const keys = Object.keys(EMPTY_GOALS_METRICS) as (keyof GoalMetrics)[];

    return keys.every((key) => first[key] === second[key]);
  }

  private async findByUserIdSafe(
    userId: string,
    executor: Pick<Db, 'select'> = this.db,
  ) {
    const [goals] = await executor
      .select()
      .from(userGoals)
      .where(and(eq(userGoals.userId, userId), isNull(userGoals.endedAt)))
      .orderBy(desc(userGoals.startedAt))
      .limit(1);

    return goals;
  }

  private async acquireUserLock(userId: string, executor: Pick<Db, 'execute'>) {
    await executor.execute(
      sql`SELECT pg_advisory_xact_lock(hashtext(${userId}))`,
    );
  }

  private getDayRange(date: string, tz?: string) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
      throw new BadRequestException('Invalid date. Expected YYYY-MM-DD.');
    }

    const parsed = new Date(`${date}T00:00:00.000Z`);

    if (
      Number.isNaN(parsed.getTime()) ||
      parsed.toISOString().slice(0, 10) !== date
    ) {
      throw new BadRequestException('Invalid calendar date.');
    }

    return zonedDayRange(date, this.resolveTimeZone(tz));
  }

  private resolveTimeZone(tz?: string): string {
    if (!tz) return 'UTC';

    try {
      new Intl.DateTimeFormat(undefined, { timeZone: tz });
      return tz;
    } catch {
      return 'UTC';
    }
  }

  /**
   * A recommendation is a delta from the goals it evaluated. Keeping that
   * delta lets a personalized plan follow later profile/weight changes
   * without silently discarding the recommendation itself.
   */
  private async applyLatestRecommendationAdjustment(
    userId: string,
    calculated: GoalMetrics,
    executor: DatabaseExecutor,
  ): Promise<GoalMetrics> {
    const [recommendation] = await executor
      .select({
        previousGoals: goalRecommendations.previousGoals,
        recommendedGoals: goalRecommendations.recommendedGoals,
      })
      .from(goalRecommendations)
      .where(
        and(
          eq(goalRecommendations.userId, userId),
          eq(goalRecommendations.status, 'accepted'),
        ),
      )
      .orderBy(
        desc(goalRecommendations.acceptedAt),
        desc(goalRecommendations.createdAt),
      )
      .limit(1);

    if (!recommendation) return calculated;

    const adjusted = {} as GoalMetrics;

    for (const key of Object.keys(calculated) as (keyof GoalMetrics)[]) {
      const baseline = calculated[key];
      const previous = recommendation.previousGoals[key];
      const recommended = recommendation.recommendedGoals[key];

      adjusted[key] =
        baseline == null || previous == null || recommended == null
          ? baseline
          : Math.max(0, roundNutrition(baseline + (recommended - previous)));
    }

    return adjusted;
  }

  private calculateActivityGoals(activityLevel: string) {
    const goals = {
      low: {
        steps: 5000,
        activeCalories: 200,
      },
      medium: {
        steps: 8000,
        activeCalories: 400,
      },
      high: {
        steps: 10000,
        activeCalories: 600,
      },
    };

    return goals[activityLevel as keyof typeof goals] ?? goals.medium;
  }

  private calculateWorkoutGoals(activityLevel: string) {
    const goals = {
      low: {
        workouts: 2,
        minutes: 90,
      },
      medium: {
        workouts: 3,
        minutes: 150,
      },
      high: {
        workouts: 4,
        minutes: 180,
      },
    };

    return goals[activityLevel as keyof typeof goals] ?? goals.medium;
  }

  private calculateSleepGoals() {
    return {
      minMinutes: 420,
      maxMinutes: 540,
    };
  }

  private calculateBMR(
    weight: number,
    height: number,
    age: number,
    gender: string,
  ): number {
    const base = 10 * weight + 6.25 * height - 5 * age;

    return gender === 'female' ? base - 161 : base + 5;
  }

  private calculateTDEE(bmr: number, activityLevel: string): number {
    const multipliers: Record<string, number> = {
      low: 1.2,
      medium: 1.55,
      high: 1.9,
    };

    return bmr * (multipliers[activityLevel] ?? 1.2);
  }

  private adjustForGoal(tdee: number, goal: string): number {
    const adjustments: Record<string, number> = {
      lose: 0.8,
      gain: 1.15,
      maintain: 1.0,
    };

    return tdee * (adjustments[goal] ?? 1.0);
  }

  private calculateProtein(weight: number, goal: string): number {
    const perKg: Record<string, number> = {
      lose: 2.0,
      gain: 2.0,
      maintain: 1.6,
    };

    return weight * (perKg[goal] ?? 1.6);
  }
}
