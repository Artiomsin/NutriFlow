import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import { and, desc, eq, gt, gte, isNull, lt, lte, or } from 'drizzle-orm';
import type { Db } from '../db/db';
import { DB } from '../db/db.module';
import { userProfiles } from '../db/schema/userProfiles';
import { userGoals } from '../db/schema/userGoals';
import { weightLogs } from '../db/schema/weightLogs';
import { dailySummary } from '../db/schema/dailySummary';
import { dailyActivity } from '../db/schema/dailyActivity';
import { userWorkouts } from '../db/schema/userWorkouts';
import { userSleep } from '../db/schema/userSleep';
import { formatDateInTimeZone, zonedDayRange } from '../common/time/user-date';
import { rowToGoalMetrics } from './goals-history';
import {
  calculateRecommendedMetrics,
  mapProfileRowToInput,
} from './goals-calculation';
import { diffGoalMetrics } from './goal-versions';
import type { GoalMetrics } from './personalization/types';

type ProgressStatus =
  | 'on_track'
  | 'slightly_off'
  | 'off_track'
  | 'insufficient_data';
type ProgressReason = 'rate' | 'adherence' | 'both' | 'data';
type RecommendedAction =
  | 'none'
  | 'collect_data'
  | 'adjust_plan'
  | 'ease_plan'
  | 'slow_down';

function toDateStrInTz(date: Date, timeZone: string): string {
  return formatDateInTimeZone(date, timeZone);
}

function addDays(dateStr: string, days: number): string {
  const d = new Date(`${dateStr}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

function mean(values: number[]): number | null {
  if (values.length === 0) return null;
  return values.reduce((s, v) => s + v, 0) / values.length;
}

function linearTrendKgPerWeek(
  points: { date: string; weightKg: number }[],
): number | null {
  if (points.length < 2) return null;
  const sorted = [...points].sort((a, b) => a.date.localeCompare(b.date));
  const startMs = Date.parse(`${sorted[0]!.date}T00:00:00Z`);
  const xs = sorted.map(
    (p) => (Date.parse(`${p.date}T00:00:00Z`) - startMs) / 86400000,
  );
  const ys = sorted.map((p) => p.weightKg);
  const n = xs.length;
  const meanX = xs.reduce((s, x) => s + x, 0) / n;
  const meanY = ys.reduce((s, y) => s + y, 0) / n;
  let num = 0;
  let den = 0;
  for (let i = 0; i < n; i++) {
    num += (xs[i]! - meanX) * (ys[i]! - meanY);
    den += (xs[i]! - meanX) ** 2;
  }
  if (den === 0) return null;
  return (num / den) * 7;
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

@Injectable()
export class GoalsProgressService {
  constructor(@Inject(DB) private readonly db: Db) {}

  async getWeeklyProgress(userId: string, days = 14) {
    const periodDays = clamp(Math.round(days), 7, 30);
    const [profile] = await this.db
      .select()
      .from(userProfiles)
      .where(eq(userProfiles.userId, userId))
      .limit(1);
    if (!profile) throw new NotFoundException('Profile not found');

    const [activeGoal] = await this.db
      .select()
      .from(userGoals)
      .where(and(eq(userGoals.userId, userId), isNull(userGoals.endedAt)))
      .orderBy(desc(userGoals.startedAt))
      .limit(1);
    if (!activeGoal) throw new NotFoundException('Goals not found');

    const tz = profile.timeZone || 'UTC';
    const today = toDateStrInTz(new Date(), tz);
    const periodStart = addDays(today, -(periodDays - 1));
    const periodEnd = today;

    const periodStartRange = zonedDayRange(periodStart, tz);
    const periodEndRange = zonedDayRange(periodEnd, tz);

    const [
      weightRows,
      summaryRows,
      activityRows,
      workoutRows,
      sleepRows,
      goalVersionRows,
    ] = await Promise.all([
      this.db
        .select({ date: weightLogs.entryDate, weightKg: weightLogs.weightKg })
        .from(weightLogs)
        .where(
          and(
            eq(weightLogs.userId, userId),
            gte(weightLogs.entryDate, periodStart),
            lte(weightLogs.entryDate, periodEnd),
          ),
        ),
      this.db
        .select({
          date: dailySummary.date,
          calories: dailySummary.totalCalories,
          protein: dailySummary.totalProtein,
        })
        .from(dailySummary)
        .where(
          and(
            eq(dailySummary.userId, userId),
            gte(dailySummary.date, periodStart),
            lte(dailySummary.date, periodEnd),
          ),
        ),
      this.db
        .select({ date: dailyActivity.date })
        .from(dailyActivity)
        .where(
          and(
            eq(dailyActivity.userId, userId),
            gte(dailyActivity.date, periodStart),
            lte(dailyActivity.date, periodEnd),
          ),
        ),
      this.db
        .select({ date: userWorkouts.localDate })
        .from(userWorkouts)
        .where(
          and(
            eq(userWorkouts.userId, userId),
            gte(userWorkouts.localDate, periodStart),
            lte(userWorkouts.localDate, periodEnd),
          ),
        ),
      this.db
        .select({
          date: userSleep.localDate,
          asleepSeconds: userSleep.asleepSeconds,
        })
        .from(userSleep)
        .where(
          and(
            eq(userSleep.userId, userId),
            gte(userSleep.localDate, periodStart),
            lte(userSleep.localDate, periodEnd),
          ),
        ),
      this.db
        .select()
        .from(userGoals)
        .where(
          and(
            eq(userGoals.userId, userId),
            lt(userGoals.startedAt, periodEndRange.end),
            or(
              isNull(userGoals.endedAt),
              gt(userGoals.endedAt, periodStartRange.start),
            )!,
          ),
        )
        .orderBy(desc(userGoals.startedAt)),
    ]);

    const weights = weightRows.map((r) => ({
      date: r.date,
      weightKg: Number(r.weightKg),
    }));
    const nutritionDays = summaryRows
      .filter((r) => r.calories != null && Number(r.calories) > 0)
      .map((r) => ({
        date: r.date,
        calories: Number(r.calories ?? 0),
        protein: r.protein == null ? null : Number(r.protein),
      }));

    const weighInsCount = weights.length;
    const loggedDaysCount = nutritionDays.length;
    const activityDaysCount = new Set(activityRows.map((r) => r.date)).size;
    const workoutDaysCount = new Set(workoutRows.map((r) => r.date)).size;
    const sleepNightsCount = sleepRows.filter(
      (r) => r.asleepSeconds != null,
    ).length;

    const sufficient = weighInsCount >= 3 && loggedDaysCount >= 4;

    const applied = rowToGoalMetrics(activeGoal);
    const goalVersions =
      goalVersionRows.length > 0 ? goalVersionRows : [activeGoal];

    const findGoalForDate = (dateStr: string): GoalMetrics => {
      const { start, end } = zonedDayRange(dateStr, tz);
      const match = goalVersions.find(
        (g) => g.startedAt < end && (g.endedAt == null || g.endedAt > start),
      );
      return rowToGoalMetrics(match ?? activeGoal);
    };

    let daysInCalorieRange = 0;
    let daysInProteinRange = 0;
    let calorieTargetDays = 0;
    let proteinTargetDays = 0;
    for (const day of nutritionDays) {
      const dayGoal = findGoalForDate(day.date);
      const calorieTarget = dayGoal.dailyCaloriesGoal ?? null;
      const proteinTarget = dayGoal.dailyProteinGoal ?? null;
      if (calorieTarget && calorieTarget > 0) {
        calorieTargetDays++;
        const diff = Math.abs(day.calories - calorieTarget);
        if (diff <= calorieTarget * 0.1) daysInCalorieRange++;
      }
      if (proteinTarget && proteinTarget > 0 && day.protein != null) {
        proteinTargetDays++;
        if (day.protein >= proteinTarget * 0.9) daysInProteinRange++;
      }
    }
    const calorieAdherence =
      calorieTargetDays > 0 ? daysInCalorieRange / calorieTargetDays : null;
    const proteinAdherence =
      proteinTargetDays > 0 ? daysInProteinRange / proteinTargetDays : null;
    const avgCalories = mean(nutritionDays.map((d) => d.calories));
    const avgProtein = mean(
      nutritionDays.map((d) => d.protein).filter((v): v is number => v != null),
    );
    const calorieTarget = applied.dailyCaloriesGoal ?? null;
    const proteinTarget = applied.dailyProteinGoal ?? null;

    const actualRateKgPerWeek = linearTrendKgPerWeek(weights);
    const profileGoal =
      (profile.goal as 'lose' | 'gain' | 'maintain' | null) ?? 'maintain';

    // Target rate: prefer explicit profile pace, else derive rough default expectation.
    let targetRateKgPerWeek: number | null = null;
    let targetRateSource: 'profile' | 'derived' | 'maintain' | 'unknown';
    if (profileGoal === 'maintain') {
      targetRateKgPerWeek = 0;
      targetRateSource = 'maintain';
    } else if (profile.weeklyRateKg != null) {
      const mag = Math.abs(Number(profile.weeklyRateKg));
      targetRateKgPerWeek = profileGoal === 'lose' ? -mag : mag;
      targetRateSource = 'profile';
    } else if (profile.targetWeightKg != null && profile.weight != null) {
      const delta = Number(profile.targetWeightKg) - Number(profile.weight);
      if (
        (profileGoal === 'lose' && delta < 0) ||
        (profileGoal === 'gain' && delta > 0)
      ) {
        // If no date, assume a moderate default pace as reference target.
        const mag = profileGoal === 'lose' ? 0.5 : 0.25;
        targetRateKgPerWeek = profileGoal === 'lose' ? -mag : mag;
        targetRateSource = 'derived';
      } else {
        targetRateKgPerWeek = profileGoal === 'lose' ? -0.5 : 0.25;
        targetRateSource = 'derived';
      }
    } else {
      targetRateKgPerWeek =
        profileGoal === 'lose' ? -0.5 : profileGoal === 'gain' ? 0.25 : 0;
      targetRateSource = 'derived';
    }

    const rateDelta =
      actualRateKgPerWeek != null && targetRateKgPerWeek != null
        ? actualRateKgPerWeek - targetRateKgPerWeek
        : null;

    const B_OK = 0.15;
    const B_OFF = 0.3;

    let status: ProgressStatus;
    let reason: ProgressReason;
    let adherenceLevel: 'high' | 'medium' | 'low' | 'unknown' = 'unknown';
    if (calorieAdherence != null) {
      adherenceLevel =
        calorieAdherence >= 0.7
          ? 'high'
          : calorieAdherence < 0.5
            ? 'low'
            : 'medium';
    }

    let direction: 'ok' | 'too_slow' | 'too_fast' | 'drift' | 'unknown' =
      'unknown';
    if (sufficient && rateDelta != null) {
      const abs = Math.abs(rateDelta);
      if (profileGoal === 'maintain') {
        direction = abs <= B_OK ? 'ok' : 'drift';
      } else if (profileGoal === 'lose') {
        if (abs <= B_OK) direction = 'ok';
        else if (rateDelta > B_OK)
          direction = 'too_slow'; // less negative than target
        else direction = 'too_fast'; // more negative than target
      } else {
        if (abs <= B_OK) direction = 'ok';
        else if (rateDelta < -B_OK)
          direction = 'too_slow'; // less positive than target
        else direction = 'too_fast';
      }

      if (direction === 'ok') {
        status = adherenceLevel === 'low' ? 'slightly_off' : 'on_track';
        reason = adherenceLevel === 'low' ? 'adherence' : 'rate';
      } else if (Math.abs(rateDelta) > B_OFF) {
        status = 'off_track';
        reason =
          adherenceLevel === 'high' || adherenceLevel === 'medium'
            ? 'rate'
            : 'both';
      } else {
        status = 'slightly_off';
        reason =
          adherenceLevel === 'low'
            ? 'both'
            : adherenceLevel === 'high'
              ? 'rate'
              : 'both';
      }
    } else if (!sufficient) {
      status = 'insufficient_data';
      reason = 'data';
    } else {
      status = 'insufficient_data';
      reason = 'data';
    }

    // Recommendation action aligned with agreed logic
    let action: RecommendedAction = 'none';
    let recommendationText = 'Всё по плану, менять ничего не нужно.';
    let suggestedAdjustment: {
      metrics: GoalMetrics;
      diff: ReturnType<typeof diffGoalMetrics>;
      note?: string;
      basis?: Record<string, unknown>;
    } | null = null;

    const profileInput = mapProfileRowToInput(profile);

    const buildRateAdjustment = (
      newRateKgPerWeek: number | null,
      note?: string,
    ) => {
      if (!profileInput) return null;
      const adjustedProfile = {
        ...profileInput,
        weeklyRateKg: newRateKgPerWeek,
      };
      const calc = calculateRecommendedMetrics(adjustedProfile);
      const diff = diffGoalMetrics(applied, calc.metrics);
      if (diff.length === 0) return null;
      const safetyNote = calc.calories.limitedBySafety
        ? 'Ограничено безопасными пределами.'
        : undefined;
      return {
        metrics: calc.metrics,
        diff,
        note: note ?? safetyNote,
        basis: {
          previousWeeklyRateKg: profile.weeklyRateKg ?? null,
          newWeeklyRateKg: newRateKgPerWeek,
          paceSource: calc.calories.paceSource,
          dailyDeltaKcal: calc.calories.dailyDeltaKcal,
          warnings: calc.calories.warnings,
        },
      };
    };

    if (status === 'insufficient_data') {
      action = 'collect_data';
      recommendationText =
        'Недостаточно данных для надёжного вывода. Продолжайте взвешиваться (>= 3 раз за период) и вести записи питания (>= 4 дней), план менять не нужно.';
    } else if (status === 'on_track') {
      action = 'none';
      recommendationText =
        'Всё по плану, менять ничего не нужно. Тренд и соблюдение в пределах ожидаемого.';
    } else if (direction === 'too_fast') {
      action = 'slow_down';
      recommendationText =
        'Темп изменения веса устойчиво быстрее целевого. Рекомендуется скорректировать план для более безопасного и устойчивого темпа.';
      const currentMag =
        profile.weeklyRateKg != null
          ? Math.abs(Number(profile.weeklyRateKg))
          : targetRateKgPerWeek
            ? Math.abs(targetRateKgPerWeek)
            : profileGoal === 'lose'
              ? 0.5
              : 0.25;
      const saferMag = Math.max(
        profileGoal === 'lose' ? 0.25 : 0.1,
        currentMag * 0.8,
      );
      suggestedAdjustment = buildRateAdjustment(
        saferMag,
        'Темп смягчён для большей безопасности и устойчивости.',
      );
    } else if (direction === 'too_slow' || direction === 'drift') {
      if (adherenceLevel === 'high') {
        action = 'adjust_plan';
        recommendationText =
          'Темп устойчиво отклоняется от плана при хорошем соблюдении. Возможна умеренная корректировка плана в безопасных пределах.';
        const baseMag =
          profile.weeklyRateKg != null
            ? Math.abs(Number(profile.weeklyRateKg))
            : targetRateKgPerWeek
              ? Math.abs(targetRateKgPerWeek)
              : profileGoal === 'lose'
                ? 0.5
                : profileGoal === 'gain'
                  ? 0.25
                  : 0;
        let newMag: number;
        if (profileGoal === 'lose') newMag = clamp(baseMag + 0.1, 0.25, 1.0);
        else if (profileGoal === 'gain')
          newMag = clamp(baseMag + 0.1, 0.1, 0.5);
        else newMag = 0;
        suggestedAdjustment =
          profileGoal === 'maintain'
            ? buildRateAdjustment(
                0,
                'Небольшая корректировка для возврата к поддержанию.',
              )
            : buildRateAdjustment(
                newMag,
                'Умеренная корректировка темпа в безопасных пределах.',
              );
      } else {
        action = 'ease_plan';
        recommendationText =
          'План может быть трудновыполним при текущем соблюдении. Рекомендуется упростить цель (более реалистичный шаг/калорийность) вместо ужесточения.';
        const easedMag =
          profileGoal === 'lose' ? 0.25 : profileGoal === 'gain' ? 0.1 : null;
        suggestedAdjustment = buildRateAdjustment(
          easedMag,
          'План смягчён для лучшей выполнимости.',
        );
      }
    } else if (status === 'slightly_off' || status === 'off_track') {
      if (adherenceLevel === 'low') {
        action = 'ease_plan';
        recommendationText =
          'Соблюдение плана низкое. Рекомендуется упростить цель и сфокусироваться на регулярности.';
        const easedMag =
          profileGoal === 'lose' ? 0.25 : profileGoal === 'gain' ? 0.1 : null;
        suggestedAdjustment = buildRateAdjustment(
          easedMag,
          'План смягчён для лучшей выполнимости.',
        );
      } else {
        action = 'none';
        recommendationText =
          'Есть небольшие отклонения, но выраженной устойчивой проблемы не выявлено. Продолжайте наблюдение.';
      }
    }

    const targetWeightMinKg =
      (profile as any).targetWeightMinKg == null
        ? null
        : Number((profile as any).targetWeightMinKg);
    const targetWeightMaxKg =
      (profile as any).targetWeightMaxKg == null
        ? null
        : Number((profile as any).targetWeightMaxKg);

    const achievement = this.detectGoalAchievement({
      profileGoal,
      targetWeightKg:
        profile.targetWeightKg == null ? null : Number(profile.targetWeightKg),
      targetWeightMinKg,
      targetWeightMaxKg,
      weights,
      actualRateKgPerWeek,
      sufficient,
    });

    const progressToTarget = (() => {
      const target =
        profile.targetWeightKg == null ? null : Number(profile.targetWeightKg);
      const currentTrendWeight = achievement.trendWeightKg;
      if (currentTrendWeight == null) return null;
      if (profileGoal === 'maintain') {
        const min = targetWeightMinKg;
        const max = targetWeightMaxKg;
        if (min != null && max != null) {
          const inRange =
            currentTrendWeight >= min && currentTrendWeight <= max;
          const belowRange = currentTrendWeight < min;
          const aboveRange = currentTrendWeight > max;
          const distanceToRangeKg = belowRange
            ? Math.round((min - currentTrendWeight) * 10) / 10
            : aboveRange
              ? Math.round((currentTrendWeight - max) * 10) / 10
              : 0;
          return {
            mode: 'range' as const,
            targetWeightMinKg: min,
            targetWeightMaxKg: max,
            targetWeightKg: target,
            currentTrendWeightKg: currentTrendWeight,
            deltaKg:
              Math.round(((min + max) / 2 - currentTrendWeight) * 10) / 10,
            inRange,
            belowRange,
            aboveRange,
            distanceToRangeKg,
          };
        }
        if (target == null) return null;
        const diff = Math.abs(currentTrendWeight - target);
        return {
          mode: 'anchor' as const,
          targetWeightKg: target,
          currentTrendWeightKg: currentTrendWeight,
          deltaKg: Math.round((target - currentTrendWeight) * 10) / 10,
          inRange: diff <= 1.0,
          toleranceKg: 1.0,
        };
      }
      if (target == null) return null;
      return {
        targetWeightKg: target,
        currentTrendWeightKg: currentTrendWeight,
        remainingKg: Math.round((target - currentTrendWeight) * 10) / 10,
      };
    })();

    const estimatedCompletion = (() => {
      const target =
        profile.targetWeightKg == null ? null : Number(profile.targetWeightKg);
      const currentTrendWeight = achievement.trendWeightKg;
      if (
        !sufficient ||
        target == null ||
        currentTrendWeight == null ||
        profileGoal === 'maintain'
      ) {
        return null;
      }

      const remainingToTarget = target - currentTrendWeight; // signed: lose negative, gain positive
      const distance = Math.abs(remainingToTarget);
      if (distance < 0.1) {
        return {
          plannedDate: periodEnd,
          byTrendDate: periodEnd,
          basis: 'already_at_target_by_trend',
        };
      }

      const calcEta = (rateKgPerWeek: number | null): string | null => {
        if (
          rateKgPerWeek == null ||
          !Number.isFinite(rateKgPerWeek) ||
          rateKgPerWeek === 0
        )
          return null;
        // Rate must move toward target.
        if (remainingToTarget < 0 && rateKgPerWeek >= 0) return null; // need to lose, but not losing
        if (remainingToTarget > 0 && rateKgPerWeek <= 0) return null; // need to gain, but not gaining
        const weeks = distance / Math.abs(rateKgPerWeek);
        if (!Number.isFinite(weeks) || weeks > 520) return null; // cap at ~10 years to avoid nonsense
        const days = Math.ceil(weeks * 7);
        return addDays(periodEnd, days);
      };

      const plannedDate = calcEta(targetRateKgPerWeek);
      const byTrendDate = calcEta(actualRateKgPerWeek);
      if (!plannedDate && !byTrendDate) return null;

      return {
        plannedDate, // ETA if user follows target pace
        byTrendDate, // ETA if current trend continues
        remainingKg: Math.round(remainingToTarget * 10) / 10,
        actualRateKgPerWeek,
        targetRateKgPerWeek,
        isApproximate: true,
      };
    })();

    return {
      period: {
        start: periodStart,
        end: periodEnd,
        days: periodDays,
        timeZone: tz,
      },
      status,
      reason,
      direction,
      confidence: sufficient
        ? weighInsCount >= 5 && loggedDaysCount >= 7
          ? 'high'
          : 'medium'
        : 'low',
      metrics: {
        actualRateKgPerWeek,
        targetRateKgPerWeek,
        targetRateSource,
        rateDeltaKgPerWeek: rateDelta,
        weighInsCount,
        loggedDaysCount,
        activityDaysCount,
        workoutDaysCount,
        sleepNightsCount,
        calorieAdherence,
        proteinAdherence,
        avgCalories,
        avgProtein,
        calorieTarget,
        proteinTarget,
      },
      recommendation: {
        action,
        text: recommendationText,
        nothingToChange: action === 'none',
        suggestedAdjustment,
      },
      achievement,
      progressToTarget,
      estimatedCompletion,
      appliedGoals: applied,
      goal: {
        type: profileGoal,
        targetWeightKg: profile.targetWeightKg ?? null,
        weeklyRateKg: profile.weeklyRateKg ?? null,
        targetDate: profile.targetDate ?? null,
        goalStartedAt: profile.goalStartedAt
          ? profile.goalStartedAt.toISOString()
          : null,
        mode: (activeGoal.mode as string | null) ?? 'auto',
      },
    };
  }

  private detectGoalAchievement(args: {
    profileGoal: 'lose' | 'gain' | 'maintain';
    targetWeightKg: number | null;
    targetWeightMinKg: number | null;
    targetWeightMaxKg: number | null;
    weights: { date: string; weightKg: number }[];
    actualRateKgPerWeek: number | null;
    sufficient: boolean;
  }) {
    const {
      profileGoal,
      targetWeightKg,
      targetWeightMinKg,
      targetWeightMaxKg,
      weights,
      sufficient,
    } = args;
    if (!sufficient || weights.length < 3) {
      return {
        achieved: false,
        status: 'insufficient_data' as const,
        message:
          'Недостаточно данных для определения достижения цели по тренду.',
        trendWeightKg: null,
      };
    }

    const trendWeightKg = this.trendWeightAtEnd(weights);
    if (trendWeightKg == null) {
      return {
        achieved: false,
        status: 'insufficient_data' as const,
        message:
          'Недостаточно данных для определения достижения цели по тренду.',
        trendWeightKg: null,
      };
    }

    if (profileGoal === 'maintain') {
      const hasRange = targetWeightMinKg != null && targetWeightMaxKg != null;
      if (hasRange) {
        const inRange =
          trendWeightKg >= targetWeightMinKg! &&
          trendWeightKg <= targetWeightMaxKg!;
        const belowRange = trendWeightKg < targetWeightMinKg!;
        const aboveRange = trendWeightKg > targetWeightMaxKg!;
        const recent = weights.slice(-5);
        const recentInRangeCount = recent.filter(
          (w) =>
            w.weightKg >= targetWeightMinKg! &&
            w.weightKg <= targetWeightMaxKg!,
        ).length;
        const stable =
          recent.length >= 3
            ? recentInRangeCount >= Math.min(3, recent.length)
            : inRange;
        const achieved = inRange && stable;
        return {
          achieved,
          status: achieved
            ? ('maintaining' as const)
            : inRange
              ? ('stabilizing' as const)
              : ('not_achieved' as const),
          message: achieved
            ? 'Вес стабильно удерживается в целевом диапазоне по тренду.'
            : inRange
              ? 'Вес в диапазоне по тренду, но стабильность ещё подтверждается.'
              : belowRange
                ? 'Вес по тренду ниже целевого диапазона удержания.'
                : 'Вес по тренду выше целевого диапазона удержания.',
          trendWeightKg,
          targetWeightKg,
          targetWeightMinKg,
          targetWeightMaxKg,
          inRange,
          belowRange,
          aboveRange,
          stableInRange: achieved,
          recentInRangeCount,
          recentCount: recent.length,
        };
      }

      if (targetWeightKg == null) {
        return {
          achieved: false,
          status: 'not_applicable' as const,
          message: 'Целевой вес/диапазон для поддержания не задан.',
          trendWeightKg,
        };
      }
      const diff = Math.abs(trendWeightKg - targetWeightKg);
      const inRange = diff <= 1.0;
      return {
        achieved: inRange,
        status: inRange ? ('maintaining' as const) : ('not_achieved' as const),
        message: inRange
          ? 'Вес удерживается в целевом диапазоне по тренду.'
          : 'Вес по тренду выходит за диапазон удержания.',
        trendWeightKg,
        targetWeightKg,
        toleranceKg: 1.0,
        inRange,
      };
    }

    if (targetWeightKg == null) {
      return {
        achieved: false,
        status: 'not_applicable' as const,
        message: 'Целевой вес не задан.',
        trendWeightKg,
      };
    }

    const achieved =
      profileGoal === 'lose'
        ? trendWeightKg <= targetWeightKg
        : trendWeightKg >= targetWeightKg;

    return {
      achieved,
      status: achieved ? ('achieved' as const) : ('not_achieved' as const),
      message: achieved
        ? 'Цель достигнута по тренду. Можно перейти в поддержание, задать новую цель или скорректировать темп.'
        : 'Цель по тренду ещё не достигнута.',
      trendWeightKg,
      targetWeightKg,
      remainingKg: Math.round((targetWeightKg - trendWeightKg) * 10) / 10,
    };
  }

  private trendWeightAtEnd(
    points: { date: string; weightKg: number }[],
  ): number | null {
    if (points.length < 2) return null;
    const sorted = [...points].sort((a, b) => a.date.localeCompare(b.date));
    const startMs = Date.parse(`${sorted[0]!.date}T00:00:00Z`);
    const xs = sorted.map(
      (p) => (Date.parse(`${p.date}T00:00:00Z`) - startMs) / 86400000,
    );
    const ys = sorted.map((p) => p.weightKg);
    const n = xs.length;
    const meanX = xs.reduce((s, x) => s + x, 0) / n;
    const meanY = ys.reduce((s, y) => s + y, 0) / n;
    let num = 0;
    let den = 0;
    for (let i = 0; i < n; i++) {
      num += (xs[i]! - meanX) * (ys[i]! - meanY);
      den += (xs[i]! - meanX) ** 2;
    }
    if (den === 0) return sorted[sorted.length - 1]!.weightKg;
    const slope = num / den;
    const intercept = meanY - slope * meanX;
    const lastX = xs[xs.length - 1]!;
    return Math.round((intercept + slope * lastX) * 100) / 100;
  }
}
