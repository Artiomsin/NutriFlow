import {
  Inject,
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import type { Db } from '../db/db';
import { DB } from '../db/db.module';
import { userGoals } from '../db/schema/userGoals';
import type {
  GoalMode,
  GoalSource,
  GoalMetricKey,
  ManualGoalOverrides,
  UserGoals,
} from '../db/schema/userGoals';
import { userProfiles } from '../db/schema/userProfiles';
import { and, desc, eq, gt, isNull, lt, or, sql } from 'drizzle-orm';
import { formatDateInTimeZone, zonedDayRange } from '../common/time/user-date';
import { validateGoalPlanFields } from './goal-plan-validation';
import type {
  GoalsHistoryQueryDto,
  UpdateGoalsDto,
  NewCycleDto,
  GoalsPreviewDraftDto,
} from './goals.schema';
import type { GoalMetrics } from './personalization/types';
import {
  EMPTY_GOALS_METRICS,
  recordGoalHistory,
  rowToGoalMetrics,
} from './goals-history';
import { diffGoalMetrics, GOAL_METRIC_KEYS } from './goal-versions';
import type { GoalHistoryPage, GoalVersionEntry } from './goal-versions';
import {
  calculateRecommendedMetrics,
  goalMetricsEqual,
  mapProfileRowToInput,
  modeFromSource,
  buildManualModeSuggestion,
  getFixedMetricKeys,
  type GoalCalculationResult,
} from './goals-calculation';

type DatabaseExecutor = Pick<Db, 'select' | 'insert' | 'update' | 'execute'>;

export interface CalculateOptions {
  forceAutomatic?: boolean;
  reason?: string;
  trigger?:
    | 'initial'
    | 'profile_changed'
    | 'weight_changed'
    | 'manual_reset'
    | 'recalculate_requested';
  /** Manual overrides removed for the suggestion being created. */
  clearedFields?: GoalMetricKey[];
}

@Injectable()
export class GoalsService {
  constructor(@Inject(DB) private readonly db: Db) {}

  /**
   * Without date, returns the active goal state (enriched).
   * With date, returns the goal version effective during that calendar day.
   */
  async findByUserId(userId: string, date?: string, tz?: string) {
    if (date !== undefined) {
      return this.findVersionForDate(userId, date, tz);
    }
    return this.getCurrentState(userId);
  }

  async getCurrentState(userId: string, executor: DatabaseExecutor = this.db) {
    const existing = await this.findActiveRow(userId, executor);
    if (!existing) {
      throw new NotFoundException('Goals not found');
    }
    return this.toGoalState(existing);
  }

  private async findVersionForDate(userId: string, date: string, tz?: string) {
    const { start, end } = this.getDayRange(date, tz);
    const [goals] = await this.db
      .select()
      .from(userGoals)
      .where(
        and(
          eq(userGoals.userId, userId),
          lt(userGoals.startedAt, end),
          or(isNull(userGoals.endedAt), gt(userGoals.endedAt, start))!,
        ),
      )
      .orderBy(desc(userGoals.startedAt))
      .limit(1);

    if (!goals) {
      throw new NotFoundException('Goals not found');
    }

    return goals;
  }

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
    rows: UserGoals[],
    count: number,
  ): GoalVersionEntry[] {
    return rows.slice(0, count).map((row, index) => {
      const previous = rows[index + 1];
      const goal = rowToGoalMetrics(row);

      return {
        id: row.id,
        startedAt: row.startedAt.toISOString(),
        endedAt: row.endedAt ? row.endedAt.toISOString() : null,
        source: (row.source ?? 'initial') as GoalSource,
        reason: row.changeReason ?? null,
        changes: diffGoalMetrics(
          previous ? rowToGoalMetrics(previous) : null,
          goal,
        ),
        goal,
      };
    });
  }

  async preview(userId: string) {
    const [profile] = await this.db
      .select()
      .from(userProfiles)
      .where(eq(userProfiles.userId, userId))
      .limit(1);

    if (!profile) {
      throw new NotFoundException('Profile not found');
    }

    const input = mapProfileRowToInput(profile);
    if (!input) {
      throw new BadRequestException(
        'Not enough profile data to calculate goals. Provide weight, height, age, gender, goal and activityLevel.',
      );
    }

    const calculation = calculateRecommendedMetrics(input);
    const existing = await this.findActiveRow(userId, this.db);
    const applied = existing ? rowToGoalMetrics(existing) : null;
    const mode: GoalMode = existing
      ? ((existing.mode as GoalMode | null) ?? modeFromSource(existing.source))
      : 'auto';
    const manualOverrides =
      (existing?.manualOverrides as ManualGoalOverrides | null) ?? null;
    const fixedMetrics = getFixedMetricKeys(manualOverrides);

    let constrainedSuggestion: ReturnType<
      typeof buildManualModeSuggestion
    > | null = null;
    if (mode === 'manual' && applied) {
      constrainedSuggestion = buildManualModeSuggestion({
        applied,
        recommended: calculation.metrics,
        overrides: manualOverrides,
        profileInput: input,
        recommendedCalories: {
          minSafeCalories: calculation.calories.minSafeCalories,
          maxSafeCalories: calculation.calories.maxSafeCalories,
        },
      });
    }

    const effectiveRecommended =
      constrainedSuggestion?.suggested ?? calculation.metrics;
    const estimatedCompletion = this.computePlannedEstimatedCompletion(
      {
        goal: profile.goal,
        targetWeightKg: profile.targetWeightKg,
        currentWeightKg: profile.weight,
        timeZone: profile.timeZone,
      },
      calculation,
    );

    return {
      mode,
      recommended: calculation.metrics,
      suggested: effectiveRecommended,
      applied,
      fixedMetrics,
      manualOverrides,
      diff: diffGoalMetrics(applied, effectiveRecommended),
      autoDiff: diffGoalMetrics(applied, calculation.metrics),
      basis: calculation.basis,
      calories: {
        bmr: calculation.calories.bmr,
        tdee: calculation.calories.tdee,
        dailyCalories: calculation.calories.dailyCalories,
        rawDailyCalories: calculation.calories.rawDailyCalories,
        dailyDeltaKcal: calculation.calories.dailyDeltaKcal,
        targetRateKgPerWeek: calculation.calories.targetRateKgPerWeek,
        paceSource: calculation.calories.paceSource,
        minSafeCalories: calculation.calories.minSafeCalories,
        maxSafeCalories: calculation.calories.maxSafeCalories,
        warnings: [
          ...(calculation.calories.warnings ?? []),
          ...(constrainedSuggestion?.warnings ?? []),
        ],
        conflicts: constrainedSuggestion?.conflicts ?? [],
        limitedBySafety: calculation.calories.limitedBySafety,
      },
      preservedFixedFields: constrainedSuggestion?.preservedFixedFields ?? [],
      recalculatedFields: constrainedSuggestion?.recalculatedFields ?? [],
      willApplyAutomatically: mode === 'auto',
      estimatedCompletion,
    };
  }

  /**
   * Calculates a plan from an onboarding draft without reading or writing a
   * profile row. The caller owns the data until the final createProfile call.
   */
  previewDraft(data: GoalsPreviewDraftDto) {
    validateGoalPlanFields({
      weight: data.weight,
      goal: data.goal,
      targetWeightKg: data.targetWeightKg ?? null,
      targetWeightMinKg: data.targetWeightMinKg ?? null,
      targetWeightMaxKg: data.targetWeightMaxKg ?? null,
      weeklyRateKg: data.weeklyRateKg ?? null,
      targetDate: data.targetDate ?? null,
      goalStartedAt: data.goalStartedAt ?? null,
    });

    const calculation = calculateRecommendedMetrics({
      weightKg: data.weight,
      heightCm: data.height,
      age: data.age,
      gender: data.gender,
      goal: data.goal,
      activityLevel: data.activityLevel,
      targetWeightKg: data.targetWeightKg ?? null,
      weeklyRateKg: data.weeklyRateKg ?? null,
      targetDate: data.targetDate ?? null,
      goalStartedAt: data.goalStartedAt ?? null,
    });

    const estimatedCompletion = this.computePlannedEstimatedCompletion(
      {
        goal: data.goal,
        targetWeightKg: data.targetWeightKg ?? null,
        currentWeightKg: data.weight,
        timeZone: data.timeZone ?? 'UTC',
      },
      calculation,
    );

    const diff = diffGoalMetrics(null, calculation.metrics);

    return {
      mode: 'auto' as const,
      recommended: calculation.metrics,
      suggested: calculation.metrics,
      applied: null,
      fixedMetrics: [],
      manualOverrides: null,
      diff,
      autoDiff: diff,
      basis: calculation.basis,
      calories: {
        bmr: calculation.calories.bmr,
        tdee: calculation.calories.tdee,
        dailyCalories: calculation.calories.dailyCalories,
        rawDailyCalories: calculation.calories.rawDailyCalories,
        dailyDeltaKcal: calculation.calories.dailyDeltaKcal,
        targetRateKgPerWeek: calculation.calories.targetRateKgPerWeek,
        paceSource: calculation.calories.paceSource,
        minSafeCalories: calculation.calories.minSafeCalories,
        maxSafeCalories: calculation.calories.maxSafeCalories,
        warnings: calculation.calories.warnings ?? [],
        conflicts: [],
        limitedBySafety: calculation.calories.limitedBySafety,
      },
      willApplyAutomatically: true,
      estimatedCompletion,
    };
  }

  async update(userId: string, data: UpdateGoalsDto) {
    return this.db.transaction(async (tx) => {
      await this.acquireUserLock(userId, tx);

      const existing = await this.findActiveRow(userId, tx);
      const patchKeys = Object.keys(data) as (keyof GoalMetrics)[];
      const nowIso = new Date().toISOString();

      if (!existing) {
        const nextMetrics: GoalMetrics = {
          ...EMPTY_GOALS_METRICS,
          ...data,
        };
        const manualOverrides: ManualGoalOverrides = {};
        for (const key of patchKeys) {
          const value = nextMetrics[key];
          if (value != null) {
            manualOverrides[key] = { value, setAt: nowIso };
          }
        }

        return this.replaceCurrentGoals(
          userId,
          undefined,
          nextMetrics,
          'user',
          'user_edit',
          tx,
          {
            mode: 'manual',
            clearSuggestion: true,
            manualOverrides,
            appliedBasis: {
              editedManually: true,
              fixedFields: Object.keys(manualOverrides),
            },
          },
        );
      }

      const nextMetrics: GoalMetrics = {
        ...rowToGoalMetrics(existing),
        ...data,
      };

      const prevOverrides =
        (existing.manualOverrides as ManualGoalOverrides | null) ?? {};
      const manualOverrides: ManualGoalOverrides = { ...prevOverrides };
      for (const key of patchKeys) {
        const value = nextMetrics[key];
        if (value == null) {
          delete manualOverrides[key];
        } else {
          manualOverrides[key] = { value, setAt: nowIso };
        }
      }

      // Manual user edit: apply immediately as manual, clear stale suggestion.
      return this.replaceCurrentGoals(
        userId,
        existing,
        nextMetrics,
        'user',
        'user_edit',
        tx,
        {
          mode: 'manual',
          clearSuggestion: true,
          manualOverrides,
          appliedBasis: {
            editedManually: true,
            fixedFields: Object.keys(manualOverrides),
          },
        },
      );
    });
  }

  async applySuggestion(userId: string, selectedMetrics?: GoalMetricKey[]) {
    return this.db.transaction(async (tx) => {
      await this.acquireUserLock(userId, tx);
      const existing = await this.findActiveRow(userId, tx);
      if (!existing) {
        throw new NotFoundException('Goals not found');
      }
      if (!existing.suggestedGoals) {
        throw new BadRequestException('No pending suggestion to apply');
      }

      const suggested = existing.suggestedGoals as GoalMetrics;
      const applied = rowToGoalMetrics(existing);
      const mode =
        (existing.mode as GoalMode | null) ?? modeFromSource(existing.source);

      let nextMetrics: GoalMetrics;
      let remainingSuggestion: GoalMetrics | null = null;

      if (!selectedMetrics || selectedMetrics.length === 0) {
        nextMetrics = { ...suggested };
      } else {
        const selected = new Set<GoalMetricKey>(selectedMetrics);
        // Nutrition consistency: if any nutrition metric selected, apply the whole nutrition group
        // from suggestion to avoid inconsistent calories/macros.
        const nutrition: GoalMetricKey[] = [
          'dailyCaloriesGoal',
          'dailyProteinGoal',
          'dailyFatGoal',
          'dailyCarbsGoal',
        ];
        if (nutrition.some((k) => selected.has(k))) {
          for (const k of nutrition) selected.add(k);
        }

        nextMetrics = { ...applied };
        for (const key of selected) {
          nextMetrics[key] = suggested[key] ?? null;
        }

        // Keep unselected suggestion fields that still differ from the new applied state.
        const remaining: GoalMetrics = { ...nextMetrics };
        let hasRemaining = false;
        for (const key of GOAL_METRIC_KEYS as GoalMetricKey[]) {
          if (selected.has(key)) {
            remaining[key] = nextMetrics[key] ?? null;
            continue;
          }
          const sugVal = suggested[key] ?? null;
          const nextVal = nextMetrics[key] ?? null;
          if (sugVal !== nextVal) {
            remaining[key] = sugVal;
            hasRemaining = true;
          } else {
            remaining[key] = nextVal;
          }
        }
        remainingSuggestion = hasRemaining ? remaining : null;
      }

      const prevOverrides =
        (existing.manualOverrides as ManualGoalOverrides | null) ?? null;
      let manualOverrides = prevOverrides;
      if (mode === 'manual' && prevOverrides) {
        const nowIso = new Date().toISOString();
        const next: ManualGoalOverrides = { ...prevOverrides };
        const keysToSync =
          selectedMetrics && selectedMetrics.length > 0
            ? new Set<GoalMetricKey>(
                selectedMetrics.length
                  ? ((): GoalMetricKey[] => {
                      const s = new Set<GoalMetricKey>(selectedMetrics);
                      const nutrition: GoalMetricKey[] = [
                        'dailyCaloriesGoal',
                        'dailyProteinGoal',
                        'dailyFatGoal',
                        'dailyCarbsGoal',
                      ];
                      if (nutrition.some((k) => s.has(k)))
                        nutrition.forEach((k) => s.add(k));
                      return Array.from(s);
                    })()
                  : [],
              )
            : new Set(GOAL_METRIC_KEYS as GoalMetricKey[]);
        for (const key of keysToSync) {
          if (next[key]) {
            const value = nextMetrics[key];
            if (value == null) delete next[key];
            else next[key] = { value, setAt: nowIso };
          }
        }
        manualOverrides = next;
      }

      // Applying a suggestion is an explicit user action, even when the
      // values came from a recommendation. Keep the current mode manual and
      // expose it as a manual change in goal history.
      const source: GoalSource =
        mode === 'manual'
          ? 'user'
          : existing.source === 'personalized'
            ? 'personalized'
            : 'initial';

      return this.replaceCurrentGoals(
        userId,
        existing,
        nextMetrics,
        source,
        selectedMetrics?.length
          ? 'suggestion_partially_applied'
          : 'suggestion_applied',
        tx,
        {
          mode,
          clearSuggestion: remainingSuggestion == null,
          suggestedGoals: remainingSuggestion,
          suggestionReason:
            remainingSuggestion == null
              ? null
              : (existing.suggestionReason ?? null),
          suggestedAt:
            remainingSuggestion == null
              ? null
              : (existing.suggestedAt ?? new Date()),
          suggestionBasis:
            remainingSuggestion == null
              ? null
              : ((existing.suggestionBasis as Record<string, unknown> | null) ??
                null),
          manualOverrides,
          appliedBasis: {
            fromSuggestion: true,
            partial: !!(selectedMetrics && selectedMetrics.length > 0),
            selectedMetrics: selectedMetrics ?? null,
            suggestionReason: existing.suggestionReason ?? null,
          },
        },
      );
    });
  }

  async dismissSuggestion(userId: string) {
    return this.db.transaction(async (tx) => {
      await this.acquireUserLock(userId, tx);
      const existing = await this.findActiveRow(userId, tx);
      if (!existing) {
        throw new NotFoundException('Goals not found');
      }
      if (!existing.suggestedGoals && !existing.suggestionReason) {
        return this.toGoalState(existing);
      }
      const [updated] = await tx
        .update(userGoals)
        .set({
          suggestedGoals: null,
          suggestionReason: null,
          suggestedAt: null,
          suggestionBasis: null,
          updatedAt: new Date(),
        })
        .where(eq(userGoals.id, existing.id))
        .returning();
      return this.toGoalState(updated ?? existing);
    });
  }

  async clearManualOverrides(userId: string) {
    return this.db.transaction(async (tx) => {
      await this.acquireUserLock(userId, tx);
      const existing = await this.findActiveRow(userId, tx);
      if (!existing) {
        throw new NotFoundException('Goals not found');
      }
      const clearedFields = Object.keys(
        existing.manualOverrides as ManualGoalOverrides,
      ) as GoalMetricKey[];
      await tx
        .update(userGoals)
        .set({ manualOverrides: null, updatedAt: new Date() })
        .where(eq(userGoals.id, existing.id));
      // Refresh suggestion under current mode with no overrides.
      return this.calculate(userId, tx, {
        reason: 'manual_overrides_cleared',
        trigger: 'recalculate_requested',
        clearedFields,
      });
    });
  }

  async clearManualOverride(userId: string, metric: GoalMetricKey) {
    return this.db.transaction(async (tx) => {
      await this.acquireUserLock(userId, tx);
      const existing = await this.findActiveRow(userId, tx);
      if (!existing) {
        throw new NotFoundException('Goals not found');
      }
      const prev =
        (existing.manualOverrides as ManualGoalOverrides | null) ?? null;
      if (!prev || !(metric in prev)) {
        return this.toGoalState(existing);
      }
      const next: ManualGoalOverrides = { ...prev };
      delete next[metric];
      const normalized = Object.keys(next).length > 0 ? next : null;
      await tx
        .update(userGoals)
        .set({ manualOverrides: normalized, updatedAt: new Date() })
        .where(eq(userGoals.id, existing.id));
      return this.calculate(userId, tx, {
        reason: 'manual_override_cleared',
        trigger: 'recalculate_requested',
        clearedFields: [metric],
      });
    });
  }

  async applyGoalMetrics(
    userId: string,
    metrics: GoalMetrics,
    options?: {
      reason?: string;
      source?: GoalSource;
      mode?: GoalMode;
      appliedBasis?: Record<string, unknown> | null;
    },
  ) {
    return this.db.transaction(async (tx) => {
      await this.acquireUserLock(userId, tx);
      const existing = await this.findActiveRow(userId, tx);
      if (!existing) {
        throw new NotFoundException('Goals not found');
      }
      const mode =
        options?.mode ??
        (existing.mode as GoalMode | null) ??
        modeFromSource(existing.source);
      const source =
        options?.source ?? (mode === 'manual' ? 'user' : 'initial');

      const prevOverrides =
        (existing.manualOverrides as ManualGoalOverrides | null) ?? null;
      let manualOverrides = prevOverrides;
      if (prevOverrides && mode === 'manual') {
        const nowIso = new Date().toISOString();
        const next: ManualGoalOverrides = { ...prevOverrides };
        for (const key of Object.keys(prevOverrides) as (keyof GoalMetrics)[]) {
          const value = metrics[key];
          if (value == null) delete next[key];
          else next[key] = { value, setAt: nowIso };
        }
        manualOverrides = next;
      } else if (mode === 'auto') {
        manualOverrides = null;
      }

      return this.replaceCurrentGoals(
        userId,
        existing,
        metrics,
        source,
        options?.reason ?? 'progress_adjustment_applied',
        tx,
        {
          mode,
          clearSuggestion: true,
          manualOverrides,
          clearManualOverrides: mode === 'auto',
          appliedBasis: options?.appliedBasis ?? {
            fromProgressAdjustment: true,
          },
        },
      );
    });
  }

  /**
   * Recalculate goals from current profile.
   * - no active goal: create initial (auto, applied)
   * - forceAutomatic: apply recommended (auto), clear suggestion
   * - auto mode: apply if changed, clear suggestion
   * - manual mode: keep applied, store/update suggestion when different
   */
  async calculate(
    userId: string,
    executor?: DatabaseExecutor,
    optionsOrForce?: boolean | CalculateOptions,
  ) {
    const options: CalculateOptions =
      typeof optionsOrForce === 'boolean'
        ? { forceAutomatic: optionsOrForce }
        : (optionsOrForce ?? {});

    if (executor) {
      await this.acquireUserLock(userId, executor);
      return this.calculateWithExecutor(userId, executor, options);
    }

    return this.db.transaction(async (tx) => {
      await this.acquireUserLock(userId, tx);
      return this.calculateWithExecutor(userId, tx, options);
    });
  }

  async resetToAutomatic(userId: string) {
    return this.calculate(userId, undefined, {
      forceAutomatic: true,
      reason: 'manual_reset_to_automatic',
      trigger: 'manual_reset',
    });
  }

  async startNewCycle(userId: string, data: NewCycleDto) {
    return this.db.transaction(async (tx) => {
      await this.acquireUserLock(userId, tx);

      const [profile] = await tx
        .select()
        .from(userProfiles)
        .where(eq(userProfiles.userId, userId))
        .limit(1);
      if (!profile) throw new NotFoundException('Profile not found');

      const existing = await this.findActiveRow(userId, tx);
      if (!existing) throw new NotFoundException('Goals not found');

      const now = new Date();
      const nextGoal =
        data.action === 'maintain'
          ? 'maintain'
          : data.action === 'set_new_goal'
            ? (data.goal ?? profile.goal ?? 'maintain')
            : ((profile.goal as 'lose' | 'gain' | 'maintain' | null) ??
              'maintain');

      let nextTargetWeightKg =
        data.targetWeightKg === undefined
          ? profile.targetWeightKg
          : data.targetWeightKg;
      let nextTargetWeightMinKg =
        data.targetWeightMinKg === undefined
          ? ((profile as any).targetWeightMinKg ?? null)
          : data.targetWeightMinKg;
      let nextTargetWeightMaxKg =
        data.targetWeightMaxKg === undefined
          ? ((profile as any).targetWeightMaxKg ?? null)
          : data.targetWeightMaxKg;
      let nextWeeklyRateKg =
        data.weeklyRateKg === undefined
          ? profile.weeklyRateKg
          : data.weeklyRateKg;
      let nextTargetDate =
        data.targetDate === undefined ? profile.targetDate : data.targetDate;
      const nextGoalStartedAt = data.goalStartedAt ?? now;

      if (data.action === 'maintain') {
        // Maintain: prefer explicit range; default to a small range around current weight.
        const current = profile.weight == null ? null : Number(profile.weight);
        const rangeProvided =
          data.targetWeightMinKg !== undefined ||
          data.targetWeightMaxKg !== undefined;
        if (!rangeProvided && data.targetWeightKg === undefined) {
          if (current != null) {
            nextTargetWeightMinKg = Math.max(
              20,
              Math.round((current - 1) * 10) / 10,
            );
            nextTargetWeightMaxKg = Math.min(
              400,
              Math.round((current + 1) * 10) / 10,
            );
            nextTargetWeightKg = Math.round(current * 10) / 10;
          } else {
            nextTargetWeightMinKg = null;
            nextTargetWeightMaxKg = null;
            nextTargetWeightKg = null;
          }
        } else if (!rangeProvided && data.targetWeightKg !== undefined) {
          // Backward compat: anchor only.
          nextTargetWeightMinKg = null;
          nextTargetWeightMaxKg = null;
        }
        if (data.weeklyRateKg === undefined) nextWeeklyRateKg = null;
        if (data.targetDate === undefined) nextTargetDate = null;
      }

      if (data.action === 'set_new_goal') {
        if (data.targetWeightKg === undefined) nextTargetWeightKg = null;
        if (data.targetWeightMinKg === undefined) nextTargetWeightMinKg = null;
        if (data.targetWeightMaxKg === undefined) nextTargetWeightMaxKg = null;
        if (data.weeklyRateKg === undefined) nextWeeklyRateKg = null;
        if (data.targetDate === undefined) nextTargetDate = null;
        // Range only makes sense for maintain.
        if (nextGoal !== 'maintain') {
          nextTargetWeightMinKg = null;
          nextTargetWeightMaxKg = null;
        }
      }

      if (data.action === 'adjust_tempo' && nextGoal !== 'maintain') {
        nextTargetWeightMinKg = null;
        nextTargetWeightMaxKg = null;
      }

      // Basic semantic validation on merged profile.
      validateGoalPlanFields({
        weight: profile.weight,
        goal: nextGoal,
        targetWeightKg: nextTargetWeightKg,
        targetWeightMinKg: nextTargetWeightMinKg,
        targetWeightMaxKg: nextTargetWeightMaxKg,
        weeklyRateKg: nextWeeklyRateKg,
        targetDate: nextTargetDate,
        goalStartedAt: nextGoalStartedAt,
      });

      await tx
        .update(userProfiles)
        .set({
          goal: nextGoal,
          targetWeightKg: nextTargetWeightKg,
          targetWeightMinKg: nextTargetWeightMinKg,
          targetWeightMaxKg: nextTargetWeightMaxKg,
          weeklyRateKg: nextWeeklyRateKg,
          targetDate: nextTargetDate,
          goalStartedAt: nextGoalStartedAt,
          updatedAt: now,
        })
        .where(eq(userProfiles.userId, userId));

      return this.calculate(userId, tx, {
        forceAutomatic: true,
        reason: `new_cycle_${data.action}`,
        trigger: 'profile_changed',
      });
    });
  }

  private async calculateWithExecutor(
    userId: string,
    executor: DatabaseExecutor,
    options: CalculateOptions,
  ) {
    const [profile] = await executor
      .select()
      .from(userProfiles)
      .where(eq(userProfiles.userId, userId))
      .limit(1);

    if (!profile) {
      throw new NotFoundException('Profile not found');
    }

    const input = mapProfileRowToInput(profile);
    if (!input) {
      throw new BadRequestException(
        'Not enough profile data to calculate goals. Provide weight, height, age, gender, goal and activityLevel.',
      );
    }

    const calculation = calculateRecommendedMetrics(input);
    const estimatedCompletion = this.computePlannedEstimatedCompletion(
      {
        goal: profile.goal,
        targetWeightKg: profile.targetWeightKg,
        currentWeightKg: profile.weight,
        timeZone: profile.timeZone,
      },
      calculation,
    );
    const existing = await this.findActiveRow(userId, executor);

    if (!existing) {
      const reason = options.reason ?? 'initial_calculation';
      return this.replaceCurrentGoals(
        userId,
        undefined,
        calculation.metrics,
        'initial',
        reason,
        executor,
        {
          mode: 'auto',
          clearSuggestion: true,
          appliedBasis: this.buildAppliedBasis(profile, calculation),
          estimatedCompletion,
        },
      );
    }

    const mode: GoalMode = options.forceAutomatic
      ? 'auto'
      : ((existing.mode as GoalMode | null) ?? modeFromSource(existing.source));
    const applied = rowToGoalMetrics(existing);

    if (options.forceAutomatic) {
      const reason = options.reason ?? 'manual_reset_to_automatic';
      return this.replaceCurrentGoals(
        userId,
        existing,
        calculation.metrics,
        'initial',
        reason,
        executor,
        {
          mode: 'auto',
          clearSuggestion: true,
          clearManualOverrides: true,
          appliedBasis: this.buildAppliedBasis(profile, calculation),
          estimatedCompletion,
        },
      );
    }

    if (mode === 'manual') {
      // Manual mode: never overwrite applied goals. Build a coherent suggestion
      // that preserves explicit manual overrides and recalculates dependent fields.
      const manualOverrides =
        (existing.manualOverrides as ManualGoalOverrides | null) ?? null;
      const constrained = buildManualModeSuggestion({
        applied,
        recommended: calculation.metrics,
        overrides: manualOverrides,
        profileInput: input,
        recommendedCalories: {
          minSafeCalories: calculation.calories.minSafeCalories,
          maxSafeCalories: calculation.calories.maxSafeCalories,
        },
      });
      const suggestionMetrics = constrained.suggested;
      const suggestionDiffers = !goalMetricsEqual(applied, suggestionMetrics);
      const previousClearedFields =
        ((existing.suggestionBasis as Record<string, unknown> | null)
          ?.clearedFields as GoalMetricKey[] | undefined) ?? [];
      const clearedFields = [
        ...new Set([
          ...(options.clearedFields ?? []),
          ...previousClearedFields,
        ]),
      ];
      const now = new Date();
      if (suggestionDiffers) {
        const [updated] = await executor
          .update(userGoals)
          .set({
            suggestedGoals: suggestionMetrics,
            suggestionReason:
              options.reason ?? options.trigger ?? 'recalculate_requested',
            suggestedAt: now,
            suggestionBasis: {
              ...this.buildAppliedBasis(profile, calculation),
              calculatedAt: now.toISOString(),
              preservedFixedFields: constrained.preservedFixedFields,
              recalculatedFields: constrained.recalculatedFields,
              clearedFields,
              warnings: [
                ...(calculation.calories.warnings ?? []),
                ...constrained.warnings,
              ],
              conflicts: constrained.conflicts,
            },
            updatedAt: now,
          })
          .where(eq(userGoals.id, existing.id))
          .returning();
        return this.toGoalState(updated ?? existing, estimatedCompletion);
      }

      // No difference: clear stale suggestion if present.
      if (existing.suggestedGoals || existing.suggestionReason) {
        const [updated] = await executor
          .update(userGoals)
          .set({
            suggestedGoals: null,
            suggestionReason: null,
            suggestedAt: null,
            suggestionBasis: null,
            updatedAt: now,
          })
          .where(eq(userGoals.id, existing.id))
          .returning();
        return this.toGoalState(updated ?? existing, estimatedCompletion);
      }

      return this.toGoalState(existing, estimatedCompletion);
    }

    // Auto mode: apply when changed.
    const reason =
      options.reason ??
      (options.trigger === 'weight_changed'
        ? 'weight_changed'
        : options.trigger === 'profile_changed'
          ? 'profile_changed'
          : existing.source === 'personalized'
            ? 'personalized_profile_recalculation'
            : 'profile_recalculation');

    if (goalMetricsEqual(applied, calculation.metrics)) {
      // Keep applied basis fresh without creating a noisy new version.
      const [updated] = await executor
        .update(userGoals)
        .set({
          appliedBasis: this.buildAppliedBasis(profile, calculation),
          suggestedGoals: null,
          suggestionReason: null,
          suggestedAt: null,
          suggestionBasis: null,
          updatedAt: new Date(),
        })
        .where(eq(userGoals.id, existing.id))
        .returning();
      return this.toGoalState(updated ?? existing);
    }

    const source: GoalSource =
      existing.source === 'personalized' ? 'personalized' : 'initial';

    return this.replaceCurrentGoals(
      userId,
      existing,
      calculation.metrics,
      source,
      reason,
      executor,
      {
        mode: 'auto',
        clearSuggestion: true,
        clearManualOverrides: true,
        appliedBasis: this.buildAppliedBasis(profile, calculation),
        estimatedCompletion,
      },
    );
  }

  private buildAppliedBasis(
    profile: typeof userProfiles.$inferSelect,
    calculation: GoalCalculationResult,
  ) {
    return {
      currentWeightKg: profile.weight ?? null,
      heightCm: profile.height ?? null,
      age: profile.age ?? null,
      gender: profile.gender ?? null,
      goal: profile.goal ?? null,
      activityLevel: profile.activityLevel ?? null,
      targetWeightKg: profile.targetWeightKg ?? null,
      targetWeightMinKg: (profile as any).targetWeightMinKg ?? null,
      targetWeightMaxKg: (profile as any).targetWeightMaxKg ?? null,
      weeklyRateKg: profile.weeklyRateKg ?? null,
      targetDate: profile.targetDate ?? null,
      goalStartedAt: profile.goalStartedAt
        ? profile.goalStartedAt.toISOString()
        : null,
      paceSource: calculation.calories.paceSource,
      targetRateKgPerWeek: calculation.calories.targetRateKgPerWeek,
      bmr: calculation.calories.bmr,
      tdee: calculation.calories.tdee,
      dailyDeltaKcal: calculation.calories.dailyDeltaKcal,
      warnings: calculation.calories.warnings,
      limitedBySafety: calculation.calories.limitedBySafety,
    };
  }

  private computePlannedEstimatedCompletion(
    input: {
      goal: string | null;
      targetWeightKg: number | string | null;
      currentWeightKg: number | string | null;
      timeZone: string | null;
    },
    calculation: GoalCalculationResult,
  ) {
    const goal = input.goal as 'lose' | 'gain' | 'maintain' | null;
    const targetWeightKg =
      input.targetWeightKg == null ? null : Number(input.targetWeightKg);
    const currentWeightKg =
      input.currentWeightKg == null ? null : Number(input.currentWeightKg);
    const targetRateKgPerWeek = calculation.calories.targetRateKgPerWeek;

    if (
      goal == null ||
      goal === 'maintain' ||
      targetWeightKg == null ||
      currentWeightKg == null ||
      targetRateKgPerWeek == null ||
      !Number.isFinite(targetRateKgPerWeek) ||
      targetRateKgPerWeek === 0
    ) {
      return null;
    }

    const remainingToTarget = targetWeightKg - currentWeightKg; // signed
    const distance = Math.abs(remainingToTarget);
    const tz = input.timeZone ?? 'UTC';
    const today = formatDateInTimeZone(new Date(), tz);
    const addDays = (dateStr: string, days: number): string => {
      const d = new Date(`${dateStr}T00:00:00Z`);
      d.setUTCDate(d.getUTCDate() + days);
      return d.toISOString().slice(0, 10);
    };

    if (distance < 0.1) {
      return {
        plannedDate: today,
        byTrendDate: null,
        remainingKg: Math.round(remainingToTarget * 10) / 10,
        targetRateKgPerWeek,
        isApproximate: true,
        basis: 'already_at_target',
      };
    }

    // Rate must move toward target.
    if (remainingToTarget < 0 && targetRateKgPerWeek >= 0) return null;
    if (remainingToTarget > 0 && targetRateKgPerWeek <= 0) return null;

    const weeks = distance / Math.abs(targetRateKgPerWeek);
    if (!Number.isFinite(weeks) || weeks > 520) return null;
    const plannedDate = addDays(today, Math.ceil(weeks * 7));

    return {
      plannedDate, // approximate ETA if following target pace
      byTrendDate: null, // trend ETA available in GET /goals/progress
      remainingKg: Math.round(remainingToTarget * 10) / 10,
      targetRateKgPerWeek,
      isApproximate: true,
    };
  }

  private async replaceCurrentGoals(
    userId: string,
    existing: UserGoals | undefined,
    nextMetrics: GoalMetrics,
    source: GoalSource,
    reason: string,
    executor: DatabaseExecutor,
    opts?: {
      mode?: GoalMode;
      clearSuggestion?: boolean;
      suggestedGoals?: GoalMetrics | null;
      suggestionReason?: string | null;
      suggestedAt?: Date | null;
      suggestionBasis?: Record<string, unknown> | null;
      clearManualOverrides?: boolean;
      manualOverrides?: ManualGoalOverrides | null;
      appliedBasis?: Record<string, unknown> | null;
      estimatedCompletion?: Record<string, unknown> | null;
    },
  ) {
    const previousMetrics = rowToGoalMetrics(existing);
    const mode: GoalMode =
      opts?.mode ?? (source === 'user' ? 'manual' : 'auto');
    const manualOverrides = opts?.clearManualOverrides
      ? null
      : opts?.manualOverrides !== undefined
        ? opts.manualOverrides
        : ((existing?.manualOverrides as ManualGoalOverrides | null) ?? null);

    if (
      existing &&
      existing.source === source &&
      ((existing.mode as GoalMode | null) ??
        modeFromSource(existing.source)) === mode &&
      goalMetricsEqual(previousMetrics, nextMetrics) &&
      !opts?.appliedBasis &&
      opts?.manualOverrides === undefined &&
      !opts?.clearManualOverrides
    ) {
      if (
        opts?.clearSuggestion &&
        (existing.suggestedGoals || existing.suggestionReason)
      ) {
        const [updated] = await executor
          .update(userGoals)
          .set({
            suggestedGoals: null,
            suggestionReason: null,
            suggestedAt: null,
            suggestionBasis: null,
            updatedAt: new Date(),
          })
          .where(eq(userGoals.id, existing.id))
          .returning();
        return this.toGoalState(updated ?? existing, opts?.estimatedCompletion);
      }
      return this.toGoalState(existing, opts?.estimatedCompletion);
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
        mode,
        source,
        changeReason: reason,
        suggestedGoals: opts?.clearSuggestion
          ? null
          : opts?.suggestedGoals !== undefined
            ? opts.suggestedGoals
            : ((existing?.suggestedGoals as GoalMetrics | null) ?? null),
        suggestionReason: opts?.clearSuggestion
          ? null
          : opts?.suggestionReason !== undefined
            ? opts.suggestionReason
            : (existing?.suggestionReason ?? null),
        suggestedAt: opts?.clearSuggestion
          ? null
          : opts?.suggestedAt !== undefined
            ? opts.suggestedAt
            : (existing?.suggestedAt ?? null),
        suggestionBasis: opts?.clearSuggestion
          ? null
          : opts?.suggestionBasis !== undefined
            ? opts.suggestionBasis
            : ((existing?.suggestionBasis as Record<string, unknown> | null) ??
              null),
        appliedBasis: opts?.appliedBasis ?? null,
        manualOverrides,
        startedAt: now,
        endedAt: null,
        createdAt: now,
        updatedAt: now,
      })
      .returning();

    if (!created) {
      throw new Error('Failed to create goal version');
    }

    await recordGoalHistory(
      userId,
      previousMetrics,
      rowToGoalMetrics(created),
      source,
      reason,
      executor,
    );

    return this.toGoalState(created, opts?.estimatedCompletion);
  }

  private toGoalState(
    row: UserGoals,
    estimatedCompletion?: Record<string, unknown> | null,
  ) {
    const applied = rowToGoalMetrics(row);
    const suggested = (row.suggestedGoals as GoalMetrics | null) ?? null;
    const mode = (row.mode as GoalMode | null) ?? modeFromSource(row.source);
    const manualOverrides =
      (row.manualOverrides as ManualGoalOverrides | null) ?? null;
    const fixedMetrics = getFixedMetricKeys(manualOverrides);
    const suggestion =
      suggested != null
        ? {
            goals: suggested,
            reason: row.suggestionReason ?? null,
            suggestedAt: row.suggestedAt ? row.suggestedAt.toISOString() : null,
            basis:
              (row.suggestionBasis as Record<string, unknown> | null) ?? null,
            diff: diffGoalMetrics(applied, suggested),
          }
        : null;

    return {
      ...row,
      mode,
      manualOverrides,
      fixedMetrics,
      suggestion,
      hasPendingSuggestion: suggestion != null,
      ...(estimatedCompletion !== undefined ? { estimatedCompletion } : {}),
    };
  }

  private async findActiveRow(
    userId: string,
    executor: Pick<Db, 'select'>,
  ): Promise<UserGoals | undefined> {
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
}
