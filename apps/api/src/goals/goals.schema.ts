import { z } from 'zod';
import { roundNutrition } from '../common/nutrition/precision';

const nutritionGoal = z
  .number()
  .finite()
  .positive()
  .transform(roundNutrition)
  .nullable()
  .optional();

export const updateGoalsSchema = z
  .object({
    dailyCaloriesGoal: nutritionGoal,
    dailyProteinGoal: nutritionGoal,
    dailyFatGoal: nutritionGoal,
    dailyCarbsGoal: nutritionGoal,
    dailyWaterGoal: z.number().int().positive().nullable().optional(),
    dailyStepsGoal: z.number().int().positive().nullable().optional(),
    dailyActiveCaloriesGoal: z.number().int().positive().nullable().optional(),
    weeklyWorkoutsGoal: z.number().int().positive().nullable().optional(),
    weeklyWorkoutMinutesGoal: z.number().int().positive().nullable().optional(),
    nightlySleepMinMinutes: z.number().int().positive().nullable().optional(),
    nightlySleepMaxMinutes: z.number().int().positive().nullable().optional(),
  })
  .refine(
    (value) => {
      if (
        value.nightlySleepMinMinutes == null ||
        value.nightlySleepMaxMinutes == null
      ) {
        return true;
      }
      return value.nightlySleepMinMinutes <= value.nightlySleepMaxMinutes;
    },
    {
      message: 'nightlySleepMinMinutes must not exceed nightlySleepMaxMinutes',
      path: ['nightlySleepMaxMinutes'],
    },
  );
export type UpdateGoalsDto = z.infer<typeof updateGoalsSchema>;
