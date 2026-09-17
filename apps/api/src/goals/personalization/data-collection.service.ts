import { Injectable, NotFoundException } from '@nestjs/common';
import { db } from '../../db/db';
import { weightLogs } from '../../db/schema/weightLogs';
import { dailyActivity } from '../../db/schema/dailyActivity';
import { dailySummary } from '../../db/schema/dailySummary';
import { userWorkouts } from '../../db/schema/userWorkouts';
import { userSleep } from '../../db/schema/userSleep';
import { userProfiles } from '../../db/schema/userProfiles';
import { userGoals } from '../../db/schema/userGoals';
import { eq, and, gte, lte } from 'drizzle-orm';
import type {
  ActivityDayData,
  AnalysisInput,
  GoalMetrics,
  NutritionDayData,
  ProfileData,
  SleepData,
  WeightLogData,
  WorkoutData,
} from './types';

export interface CollectedData {
  profile: ProfileData;
  currentGoals: GoalMetrics;
  input: AnalysisInput;
}

export const ANALYSIS_DAYS = 14;

function toDateStr(date: Date): string {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
}

@Injectable()
export class DataCollectionService {
  async collect(userId: string): Promise<CollectedData> {
    const profileRow = await db
      .select()
      .from(userProfiles)
      .where(eq(userProfiles.userId, userId))
      .limit(1);

    if (!profileRow[0]) {
      throw new NotFoundException('Profile not found');
    }

    const goalsRow = await db
      .select()
      .from(userGoals)
      .where(eq(userGoals.userId, userId))
      .limit(1);

    const now = new Date();
    const start = new Date(now);
    start.setDate(start.getDate() - (ANALYSIS_DAYS - 1));
    const periodStart = toDateStr(start);
    const periodEnd = toDateStr(now);

    const startTimestamp = start;
    const endTimestamp = new Date(now.getTime() + 24 * 60 * 60 * 1000 - 1);

    const [weightRows, activityRows, summaryRows, workoutRows, sleepRows] =
      await Promise.all([
        db
          .select()
          .from(weightLogs)
          .where(
            and(
              eq(weightLogs.userId, userId),
              gte(weightLogs.entryDate, periodStart),
              lte(weightLogs.entryDate, periodEnd),
            ),
          ),
        db
          .select()
          .from(dailyActivity)
          .where(
            and(
              eq(dailyActivity.userId, userId),
              gte(dailyActivity.date, periodStart),
              lte(dailyActivity.date, periodEnd),
            ),
          ),
        db
          .select()
          .from(dailySummary)
          .where(
            and(
              eq(dailySummary.userId, userId),
              gte(dailySummary.date, periodStart),
              lte(dailySummary.date, periodEnd),
            ),
          ),
        db
          .select()
          .from(userWorkouts)
          .where(
            and(
              eq(userWorkouts.userId, userId),
              gte(userWorkouts.startDate, startTimestamp),
              lte(userWorkouts.startDate, endTimestamp),
            ),
          ),
        db
          .select()
          .from(userSleep)
          .where(
            and(
              eq(userSleep.userId, userId),
              gte(userSleep.startDate, startTimestamp),
              lte(userSleep.startDate, endTimestamp),
            ),
          ),
      ]);

    const sleepData: SleepData[] = sleepRows.map((row) => ({
      date: toDateStr(new Date(row.startDate)),
      asleepMinutes:
        row.asleepSeconds !== null
          ? Math.round(Number(row.asleepSeconds) / 60)
          : null,
    }));

    const workoutData: WorkoutData[] = workoutRows.map((row) => ({
      date: toDateStr(new Date(row.startDate)),
      durationMinutes: Math.max(
        1,
        Math.round(Number(row.durationSeconds) / 60),
      ),
    }));

    const weightData: WeightLogData[] = weightRows.map((row) => ({
      entryDate: row.entryDate,
      weightKg: Number(row.weightKg),
    }));

    const activityData: ActivityDayData[] = activityRows.map((row) => ({
      date: row.date,
      steps: row.steps ?? 0,
      activeCalories: row.activeCalories ?? 0,
    }));

    const nutritionData: NutritionDayData[] = summaryRows.map((row) => ({
      date: row.date,
      calories: row.totalCalories ?? 0,
    }));

    const profileRowData = profileRow[0];
    const profile: ProfileData = {
      gender:
        profileRowData.gender === 'male' || profileRowData.gender === 'female'
          ? profileRowData.gender
          : null,
      age: profileRowData.age ?? null,
      heightCm: profileRowData.height ?? null,
      weightKg: profileRowData.weight ?? null,
      goal:
        profileRowData.goal === 'lose' ||
        profileRowData.goal === 'gain' ||
        profileRowData.goal === 'maintain'
          ? profileRowData.goal
          : null,
      activityLevel:
        profileRowData.activityLevel === 'low' ||
        profileRowData.activityLevel === 'medium' ||
        profileRowData.activityLevel === 'high'
          ? profileRowData.activityLevel
          : null,
    };

    const goalsRowData = goalsRow[0];
    const currentGoals: GoalMetrics = goalsRowData
      ? {
          dailyCaloriesGoal: goalsRowData.dailyCaloriesGoal ?? null,
          dailyProteinGoal: goalsRowData.dailyProteinGoal ?? null,
          dailyFatGoal: goalsRowData.dailyFatGoal ?? null,
          dailyCarbsGoal: goalsRowData.dailyCarbsGoal ?? null,
          dailyWaterGoal: goalsRowData.dailyWaterGoal ?? null,
          dailyStepsGoal: goalsRowData.dailyStepsGoal ?? null,
          dailyActiveCaloriesGoal: goalsRowData.dailyActiveCaloriesGoal ?? null,
          weeklyWorkoutsGoal: goalsRowData.weeklyWorkoutsGoal ?? null,
          weeklyWorkoutMinutesGoal:
            goalsRowData.weeklyWorkoutMinutesGoal ?? null,
          nightlySleepMinMinutes: goalsRowData.nightlySleepMinMinutes ?? null,
          nightlySleepMaxMinutes: goalsRowData.nightlySleepMaxMinutes ?? null,
        }
      : {
          dailyCaloriesGoal: null,
          dailyProteinGoal: null,
          dailyFatGoal: null,
          dailyCarbsGoal: null,
          dailyWaterGoal: null,
          dailyStepsGoal: null,
          dailyActiveCaloriesGoal: null,
          weeklyWorkoutsGoal: null,
          weeklyWorkoutMinutesGoal: null,
          nightlySleepMinMinutes: null,
          nightlySleepMaxMinutes: null,
        };

    return {
      profile,
      currentGoals,
      input: {
        profile,
        currentGoals,
        weightLogs: weightData,
        activity: activityData,
        nutrition: nutritionData,
        workouts: workoutData,
        sleep: sleepData,
        periodStart,
        periodEnd,
      },
    };
  }
}
