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

export const progressQuerySchema = z.object({
  days: z.coerce.number().int().min(7).max(30).default(14),
});

export type ProgressQueryDto = z.infer<typeof progressQuerySchema>;

export const progressApplySchema = z
  .object({
    days: z.coerce.number().int().min(7).max(30).optional(),
    metrics: z
      .object({
        dailyCaloriesGoal: nutritionGoal,
        dailyProteinGoal: nutritionGoal,
        dailyFatGoal: nutritionGoal,
        dailyCarbsGoal: nutritionGoal,
        dailyWaterGoal: z.number().int().positive().nullable().optional(),
        dailyStepsGoal: z.number().int().positive().nullable().optional(),
        dailyActiveCaloriesGoal: z
          .number()
          .int()
          .positive()
          .nullable()
          .optional(),
        weeklyWorkoutsGoal: z.number().int().positive().nullable().optional(),
        weeklyWorkoutMinutesGoal: z
          .number()
          .int()
          .positive()
          .nullable()
          .optional(),
        nightlySleepMinMinutes: z
          .number()
          .int()
          .positive()
          .nullable()
          .optional(),
        nightlySleepMaxMinutes: z
          .number()
          .int()
          .positive()
          .nullable()
          .optional(),
      })
      .optional(),
  })
  .optional();

export type ProgressApplyDto = z.infer<typeof progressApplySchema>;

export const clearManualOverrideSchema = z.object({
  metric: z.enum([
    'dailyCaloriesGoal',
    'dailyProteinGoal',
    'dailyFatGoal',
    'dailyCarbsGoal',
    'dailyWaterGoal',
    'dailyStepsGoal',
    'dailyActiveCaloriesGoal',
    'weeklyWorkoutsGoal',
    'weeklyWorkoutMinutesGoal',
    'nightlySleepMinMinutes',
    'nightlySleepMaxMinutes',
  ]),
});

export type ClearManualOverrideDto = z.infer<typeof clearManualOverrideSchema>;

export const applySuggestionSchema = z
  .object({
    metrics: z
      .array(
        z.enum([
          'dailyCaloriesGoal',
          'dailyProteinGoal',
          'dailyFatGoal',
          'dailyCarbsGoal',
          'dailyWaterGoal',
          'dailyStepsGoal',
          'dailyActiveCaloriesGoal',
          'weeklyWorkoutsGoal',
          'weeklyWorkoutMinutesGoal',
          'nightlySleepMinMinutes',
          'nightlySleepMaxMinutes',
        ]),
      )
      .min(1)
      .optional(),
  })
  .optional();

export type ApplySuggestionDto = z.infer<typeof applySuggestionSchema>;

export const newCycleSchema = z
  .object({
    action: z.enum(['maintain', 'set_new_goal', 'adjust_tempo']),
    goal: z.enum(['lose', 'gain', 'maintain']).optional(),
    targetWeightKg: z.number().finite().min(20).max(400).nullable().optional(),
    targetWeightMinKg: z
      .number()
      .finite()
      .min(20)
      .max(400)
      .nullable()
      .optional(),
    targetWeightMaxKg: z
      .number()
      .finite()
      .min(20)
      .max(400)
      .nullable()
      .optional(),
    weeklyRateKg: z.number().finite().positive().max(2).nullable().optional(),
    targetDate: calendarDateSchema.nullable().optional(),
    goalStartedAt: z.coerce.date().optional(),
  })
  .superRefine((value, ctx) => {
    if (value.action === 'set_new_goal' && !value.goal) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['goal'],
        message: 'goal is required for set_new_goal',
      });
    }
    if (value.action === 'adjust_tempo') {
      if (
        value.weeklyRateKg === undefined &&
        value.targetDate === undefined &&
        value.targetWeightKg === undefined
      ) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['action'],
          message:
            'adjust_tempo requires at least one of weeklyRateKg, targetDate, targetWeightKg',
        });
      }
    }
    if (value.targetDate != null) {
      const today = new Date().toISOString().slice(0, 10);
      if (value.targetDate < today) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['targetDate'],
          message: 'targetDate must not be in the past',
        });
      }
    }
  });

export type NewCycleDto = z.infer<typeof newCycleSchema>;
