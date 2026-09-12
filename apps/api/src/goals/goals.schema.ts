import { z } from 'zod';


export const updateGoalsSchema = z.object({
  dailyCaloriesGoal: z.number().int().positive().nullable().optional(),
  dailyProteinGoal: z.number().int().positive().nullable().optional(),
  dailyFatGoal: z.number().int().positive().nullable().optional(),
  dailyCarbsGoal: z.number().int().positive().nullable().optional(),
  dailyWaterGoal: z.number().int().positive().nullable().optional(),
  dailyStepsGoal: z.number().int().positive().nullable().optional(),
  dailyActiveCaloriesGoal: z.number().int().positive().nullable().optional(),
  weeklyWorkoutsGoal: z.number().int().positive().nullable().optional(),
  weeklyWorkoutMinutesGoal: z.number().int().positive().nullable().optional(),
  nightlySleepMinMinutes: z.number().int().positive().nullable().optional(),
  nightlySleepMaxMinutes: z.number().int().positive().nullable().optional(),
});
export type UpdateGoalsDto = z.infer<typeof updateGoalsSchema>;