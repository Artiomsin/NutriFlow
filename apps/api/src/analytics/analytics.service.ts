import { Injectable, NotFoundException } from '@nestjs/common';
import { db } from '../db/db';
import { dailySummary } from '../db/schema/dailySummary';
import { userGoals } from '../db/schema/userGoals';
import { eq, and, gte, lte } from 'drizzle-orm';
import { redis } from '../redis';
@Injectable()
export class AnalyticsService {
  async getAnalytics(userId: string, period: 'week' | 'month') {
    const cacheKey = `analytics:${userId}:${period}`;
    const cached = await redis.get(cacheKey);
    if (cached) {
      return JSON.parse(cached);
    }
    const now = new Date();
    const toDate = new Date(now);
    toDate.setHours(23, 59, 59, 999);
    const fromDate = new Date(now);
    fromDate.setHours(0, 0, 0, 0);
    fromDate.setDate(fromDate.getDate() - (period === 'week' ? 6 : 29));
    const result = await this.computeAnalytics(userId, fromDate, toDate, period);
    await redis.setex(cacheKey, 300, JSON.stringify(result));
    return result;
  }
  async getCustomRange(userId: string, from: string, to: string) {
    const cacheKey = `analytics:${userId}:custom:${from}:${to}`;
    const cached = await redis.get(cacheKey);
    if (cached) {
      return JSON.parse(cached);
    }
    const fromDate = new Date(from);
    fromDate.setHours(0, 0, 0, 0);
    const toDate = new Date(to);
    toDate.setHours(23, 59, 59, 999);
    const result = await this.computeAnalytics(userId, fromDate, toDate, 'custom');
    await redis.setex(cacheKey, 300, JSON.stringify(result));
    return result;
  }
  private async computeAnalytics(
    userId: string,
    fromDate: Date,
    toDate: Date,
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
    const totalDays = Math.round(
      (toDate.getTime() - fromDate.getTime()) / (1000 * 60 * 60 * 24),
    );
    const daysTracked = days.length;
    const avgCalories = daysTracked > 0
      ? Math.round(days.reduce((s, d) => s + (d.totalCalories ?? 0), 0) / daysTracked)
      : 0;
    const avgProtein = daysTracked > 0
      ? Math.round(days.reduce((s, d) => s + (d.totalProtein ?? 0), 0) / daysTracked)
      : 0;
    const avgWater = daysTracked > 0
      ? Math.round(days.reduce((s, d) => s + (d.totalWaterMl ?? 0), 0) / daysTracked)
      : 0;
    const goalCalories = goals?.dailyCaloriesGoal ?? null;
    const goalProtein = goals?.dailyProteinGoal ?? null;
    const goalWater = goals?.dailyWaterGoal ?? null;
    const goalCaloriesPct = goalCalories && goalCalories > 0
      ? Math.round((avgCalories / goalCalories) * 100)
      : null;
    const goalProteinPct = goalProtein && goalProtein > 0
      ? Math.round((avgProtein / goalProtein) * 100)
      : null;
    const goalWaterPct = goalWater && goalWater > 0
      ? Math.round((avgWater / goalWater) * 100)
      : null;
    const streak = this.calculateStreak(days);
    const trend = this.calculateTrend(days);
    const daily = days.map((d) => {
      const cals = d.totalCalories ?? 0;
      const prot = d.totalProtein ?? 0;
      const wat = d.totalWaterMl ?? 0;
      return {
        date: d.date,
        calories: cals,
        protein: prot,
        water: wat,
        caloriesPct: goalCalories && goalCalories > 0
          ? Math.round((cals / goalCalories) * 100) : null,
        proteinPct: goalProtein && goalProtein > 0
          ? Math.round((prot / goalProtein) * 100) : null,
        waterPct: goalWater && goalWater > 0
          ? Math.round((wat / goalWater) * 100) : null,
      };
    });
    return {
      period,
      fromDate: fromDate.toISOString(),
      toDate: toDate.toISOString(),
      averageCalories: avgCalories,
      averageProtein: avgProtein,
      averageWater: avgWater,
      goalCalories,
      goalCaloriesPct,
      goalProtein,
      goalProteinPct,
      goalWater,
      goalWaterPct,
      daysTracked,
      totalDays,
      streak: streak.count,
      streakStart: streak.start,
      trend,
      daily,
    };
  }
  private calculateStreak(days: { date: Date; totalCalories: number | null }[]) {
    if (days.length === 0) {
      return { count: 0, start: null };
    }
    let count = 0;
    let start = '';
    const today = new Date();
    const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;
    const dateSet = new Set(
      days.map((d) => {
        return `${d.date.getFullYear()}-${String(d.date.getMonth() + 1).padStart(2, '0')}-${String(d.date.getDate()).padStart(2, '0')}`;
      }),
    );
    for (let i = 0; i < 365; i++) {
      const check = new Date(today);
      check.setDate(check.getDate() - i);
      const checkStr = `${check.getFullYear()}-${String(check.getMonth() + 1).padStart(2, '0')}-${String(check.getDate()).padStart(2, '0')}`;
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
}