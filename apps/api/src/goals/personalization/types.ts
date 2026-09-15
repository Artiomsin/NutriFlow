export type PrimaryGoal = 'lose' | 'gain' | 'maintain';
export type ActivityLevel = 'low' | 'medium' | 'high';
export type ConfidenceLevel = 'low' | 'medium' | 'high';

export interface ProfileData {
  gender: 'male' | 'female' | null;
  age: number | null;
  heightCm: number | null;
  weightKg: number | null;
  goal: PrimaryGoal | null;
  activityLevel: ActivityLevel | null;
}

export interface WeightLogData {
  entryDate: string;
  weightKg: number;
}

export interface ActivityDayData {
  date: string;
  steps: number;
  activeCalories: number;
}

export interface NutritionDayData {
  date: string;
  calories: number;
}

export interface WorkoutData {
  date: string;
  durationMinutes: number;
}

export interface SleepData {
  date: string;
  asleepMinutes: number | null;
}

export interface GoalMetrics {
  dailyCaloriesGoal: number | null;
  dailyProteinGoal: number | null;
  dailyFatGoal: number | null;
  dailyCarbsGoal: number | null;
  dailyWaterGoal: number | null;
  dailyStepsGoal: number | null;
  dailyActiveCaloriesGoal: number | null;
  weeklyWorkoutsGoal: number | null;
  weeklyWorkoutMinutesGoal: number | null;
  nightlySleepMinMinutes: number | null;
  nightlySleepMaxMinutes: number | null;
}

export interface AnalysisInput {
  profile: ProfileData;
  currentGoals: GoalMetrics;
  weightLogs: WeightLogData[];
  activity: ActivityDayData[];
  nutrition: NutritionDayData[];
  workouts: WorkoutData[];
  sleep: SleepData[];
  periodStart: string;
  periodEnd: string;
}

export interface BaselineResult {
  avgSteps: number | null;
  avgActiveCalories: number | null;
  avgCalories: number | null;
  avgWorkoutsPerWeek: number | null;
  avgWorkoutMinutesPerWeek: number | null;
  avgAsleepMinutes: number | null;
  weightTrendKgPerWeek: number | null;
  latestWeightKg: number | null;
}

export interface DataQualityResult {
  isEnough: boolean;
  score: number;
  trackedDays: number;
  weightLogsCount: number;
  activityDays: number;
  nutritionDays: number;
  sleepNights: number;
  workoutCount: number;
  domainSufficient: {
    nutrition: boolean;
    activity: boolean;
    workout: boolean;
    sleep: boolean;
  };
}

export interface AdherenceResult {
  caloriesPct: number | null;
  stepsPct: number | null;
  activeCaloriesPct: number | null;
  workoutsPct: number | null;
  workoutMinutesPct: number | null;
  sleepPct: number | null;
}

export type OutcomeVerdict =
  | 'good'
  | 'plateau'
  | 'too_fast'
  | 'wrong_direction'
  | 'no_data';

export interface OutcomeResult {
  weightTrendKgPerWeek: number | null;
  verdict: OutcomeVerdict;
}

export interface CrossDomainResult {
  canIncreaseLoad: boolean;
  warnings: string[];
}

export interface ConfidenceResult {
  level: ConfidenceLevel;
  score: number;
  reasons: string[];
}

export interface Recommendation {
  previousGoals: GoalMetrics;
  recommendedGoals: GoalMetrics;
  analysisPeriodStart: string;
  analysisPeriodEnd: string;
  reasons: string[];
  confidence: {
    level: ConfidenceLevel;
    dataQualityScore: number;
    trackedDays: number;
    weightLogsCount: number;
    activityDays: number;
    workoutCount: number;
    sleepNights: number;
    adherenceStepsPct: number | null;
    weightTrendKgPerWeek: number | null;
  };
  domainChanges: {
    nutrition: boolean;
    activity: boolean;
    workout: boolean;
    sleep: boolean;
  };
}
