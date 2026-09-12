import { Injectable, NotFoundException } from '@nestjs/common';
import { db } from '../db/db';
import { dailySummary } from '../db/schema/dailySummary';
import { dailyActivity } from '../db/schema/dailyActivity';
import { userGoals } from '../db/schema/userGoals';
import { userSleep } from '../db/schema/userSleep';
import { userWorkouts } from '../db/schema/userWorkouts';
import { eq, and, gte, lte } from 'drizzle-orm';
import { cacheGet, cacheSet } from '../redis';

@Injectable()
export class AnalyticsService {
  async getAnalytics(userId: string, period: 'week' | 'month') {
    const cacheKey = `analytics:${userId}:${period}`;
    const cached = await cacheGet<any>(cacheKey);
    if (cached) return cached;
    const now = new Date();
    const toDate = this.toDateStr(now);
    const from = new Date(now);
    from.setDate(from.getDate() - (period === 'week' ? 6 : 29));
    const fromDate = this.toDateStr(from);
    const result = await this.computeAnalytics(userId, fromDate, toDate, period);
    await cacheSet(cacheKey, result);
    return result;
  }
  async getCustomRange(userId: string, from: string, to: string) {
    const cacheKey = `analytics:${userId}:custom:${from}:${to}`;
    const cached = await cacheGet<any>(cacheKey);
    if (cached) return cached;
    const result = await this.computeAnalytics(userId, from, to, 'custom');
    await cacheSet(cacheKey, result);
    return result;
  }
  private async computeAnalytics(
    userId: string,
    fromDate: string,
    toDate: string,
    period: string,
  ) {
    const days = await db
      .select()
      .from(dailySummary)
      .where(
        and(
          eq(dailySummary.userId, userId),
          gte(dailySummary.date, fromDate),
          lte(dailySummary.date, toDate),
        ),
      )
      .orderBy(dailySummary.date);
    const [goals] = await db
      .select()
      .from(userGoals)
      .where(eq(userGoals.userId, userId))
      .limit(1);
    const fromMs = new Date(fromDate).getTime();
    const toMs = new Date(toDate).getTime();
    const totalDays = Math.round(
      (toMs - fromMs) / (1000 * 60 * 60 * 24),
    );
    const daysTracked = days.length;

    const activityRows = await db
      .select()
      .from(dailyActivity)
      .where(
        and(
          eq(dailyActivity.userId, userId),
          gte(dailyActivity.date, fromDate),
          lte(dailyActivity.date, toDate),
        ),
      );

    const sleepStart = new Date(`${fromDate}T00:00:00.000Z`);
    const sleepEnd = new Date(`${toDate}T23:59:59.999Z`);
    const [sleepRows, workoutRows] = await Promise.all([
      db
        .select()
        .from(userSleep)
        .where(
          and(
            eq(userSleep.userId, userId),
            gte(userSleep.startDate, sleepStart),
            lte(userSleep.startDate, sleepEnd),
          ),
        ),
      db
        .select()
        .from(userWorkouts)
        .where(
          and(
            eq(userWorkouts.userId, userId),
            gte(userWorkouts.startDate, sleepStart),
            lte(userWorkouts.startDate, sleepEnd),
          ),
        ),
    ]);
    const avgCalories = daysTracked > 0
      ? Math.round(days.reduce((s, d) => s + (d.totalCalories ?? 0), 0) / daysTracked)
      : 0;
    const avgProtein = daysTracked > 0
      ? Math.round(days.reduce((s, d) => s + (d.totalProtein ?? 0), 0) / daysTracked)
      : 0;
    const avgWater = daysTracked > 0
      ? Math.round(days.reduce((s, d) => s + (d.totalWaterMl ?? 0), 0) / daysTracked)
      : 0;
    const avgFat = daysTracked > 0
      ? Math.round(days.reduce((s, d) => s + (d.totalFat ?? 0), 0) / daysTracked)
      : 0;
    const avgCarbs = daysTracked > 0
      ? Math.round(days.reduce((s, d) => s + (d.totalCarbs ?? 0), 0) / daysTracked)
      : 0;
    const goalCalories = goals?.dailyCaloriesGoal ?? null;
    const goalProtein = goals?.dailyProteinGoal ?? null;
    const goalFat = goals?.dailyFatGoal ?? null;
    const goalCarbs = goals?.dailyCarbsGoal ?? null;
    const goalWater = goals?.dailyWaterGoal ?? null;
    const goalCaloriesPct = goalCalories && goalCalories > 0
      ? Math.round((avgCalories / goalCalories) * 100)
      : null;
    const goalProteinPct = goalProtein && goalProtein > 0
      ? Math.round((avgProtein / goalProtein) * 100)
      : null;
    const goalFatPct = goalFat && goalFat > 0
      ? Math.round((avgFat / goalFat) * 100)
      : null;
    const goalCarbsPct = goalCarbs && goalCarbs > 0
      ? Math.round((avgCarbs / goalCarbs) * 100)
      : null;
    const goalWaterPct = goalWater && goalWater > 0
      ? Math.round((avgWater / goalWater) * 100)
      : null;

    const avgSteps = activityRows.length > 0
      ? Math.round(activityRows.reduce((s, d) => s + (d.steps ?? 0), 0) / activityRows.length)
      : 0;
    const avgActiveCalories = activityRows.length > 0
      ? Math.round(activityRows.reduce((s, d) => s + (d.activeCalories ?? 0), 0) / activityRows.length)
      : 0;
    const goalSteps = goals?.dailyStepsGoal ?? null;
    const goalActiveCalories = goals?.dailyActiveCaloriesGoal ?? null;
    const goalStepsPct = goalSteps && goalSteps > 0
      ? Math.round((avgSteps / goalSteps) * 100)
      : null;
    const goalActiveCaloriesPct = goalActiveCalories && goalActiveCalories > 0
      ? Math.round((avgActiveCalories / goalActiveCalories) * 100)
      : null;

    const sleepMinMinutes = goals?.nightlySleepMinMinutes ?? null;
    const sleepMaxMinutes = goals?.nightlySleepMaxMinutes ?? null;
    const sleepNights = sleepRows.filter((n) => n.asleepSeconds != null);
    const sleepTotalNights = sleepNights.length;
    const sleepNightsInRange =
      sleepTotalNights > 0 && sleepMinMinutes && sleepMaxMinutes
        ? sleepNights.filter((n) => {
            const minutes = Number(n.asleepSeconds) / 60;
            return minutes >= sleepMinMinutes && minutes <= sleepMaxMinutes;
          }).length
        : 0;

    const workoutsDone = workoutRows.length;
    const workoutMinutes = Math.round(
      workoutRows.reduce(
        (s, w) => s + Number(w.durationSeconds) / 60,
        0,
      ),
    );
    const streak = this.calculateStreak(days);
    const trend = this.calculateTrend(days);
    const daily = days.map((d) => {
      const cals = d.totalCalories ?? 0;
      const prot = d.totalProtein ?? 0;
      const ft = d.totalFat ?? 0;
      const crb = d.totalCarbs ?? 0;
      const wat = d.totalWaterMl ?? 0;
      return {
        date: d.date,
        calories: cals,
        protein: prot,
        fat: ft,
        carbs: crb,
        water: wat,
        caloriesPct: goalCalories && goalCalories > 0
          ? Math.round((cals / goalCalories) * 100) : null,
        proteinPct: goalProtein && goalProtein > 0
          ? Math.round((prot / goalProtein) * 100) : null,
        fatPct: goalFat && goalFat > 0
          ? Math.round((ft / goalFat) * 100) : null,
        carbsPct: goalCarbs && goalCarbs > 0
          ? Math.round((crb / goalCarbs) * 100) : null,
        waterPct: goalWater && goalWater > 0
          ? Math.round((wat / goalWater) * 100) : null,
      };
    });
    return {
      period,
      fromDate,
      toDate,
      averageCalories: avgCalories,
      averageProtein: avgProtein,
      averageFat: avgFat,
      averageCarbs: avgCarbs,
      averageWater: avgWater,
      goalCalories,
      goalCaloriesPct,
      goalProtein,
      goalProteinPct,
      goalFat,
      goalFatPct,
      goalCarbs,
      goalCarbsPct,
      goalWater,
      goalWaterPct,
      daysTracked,
      totalDays,
      streak: streak.count,
      streakStart: streak.start,
      trend,
      daily,
      avgSteps,
      avgActiveCalories,
      goalSteps,
      goalStepsPct,
      goalActiveCalories,
      goalActiveCaloriesPct,
      sleepTotalNights,
      sleepNightsInRange,
      workoutsDone,
      workoutMinutes,
    };
  }
  private calculateStreak(days: { date: string; totalCalories: number | null }[]) {
    if (days.length === 0) {
      return { count: 0, start: null };
    }
    let count = 0;
    let start = '';
    const today = new Date();
    const todayStr = this.toDateStr(today);
    const dateSet = new Set(
      days.map((d) => d.date),
    );
    for (let i = 0; i < 365; i++) {
      const check = new Date(today);
      check.setDate(check.getDate() - i);
      const checkStr = this.toDateStr(check);
      if (dateSet.has(checkStr)) {
        count++;
        start = check.toISOString();
      } else {
        break;
      }
    }
    return { count, start: count > 0 ? start : null };
  }
  private calculateTrend(days: { totalCalories: number | null }[]): string {
    if (days.length < 4) {
      return 'insufficient_data';
    }
    const mid = Math.floor(days.length / 2);
    const firstHalf = days.slice(0, mid);
    const secondHalf = days.slice(mid);
    const avgFirst = firstHalf.reduce((s, d) => s + (d.totalCalories ?? 0), 0) / firstHalf.length;
    const avgSecond = secondHalf.reduce((s, d) => s + (d.totalCalories ?? 0), 0) / secondHalf.length;
    if (avgFirst === 0) return 'insufficient_data';
    const diff = ((avgSecond - avgFirst) / avgFirst) * 100;
    if (diff > 5) return 'increasing';
    if (diff < -5) return 'decreasing';
    return 'stable';
  }

  private toDateStr(date: Date): string {
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
  }
}