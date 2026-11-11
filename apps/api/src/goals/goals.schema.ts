import { z } from 'zod';
import { roundNutrition } from '../common/nutrition/precision';
import {
  calendarDateSchema,
  timeZoneSchema,
} from '../common/validation/date.schema';

export const goalsQuerySchema = z.object({
  date: calendarDateSchema.optional(),
  tz: timeZoneSchema.optional(),
});

export type GoalsQueryDto = z.infer<typeof goalsQuerySchema>;

export const goalsHistoryQuerySchema = z.object({
  // When present, returns every version that was in effect during that
  // calendar day instead of a paginated page.
  date: calendarDateSchema.optional(),
  tz: timeZoneSchema.optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  // Id of the last version on the previous page.
  cursor: z.string().uuid().optional(),
});

export type GoalsHistoryQueryDto = z.infer<typeof goalsHistoryQuerySchema>;

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
