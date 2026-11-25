import { z } from 'zod';
import { roundNutrition } from '../common/nutrition/precision';
import {
  calendarDateSchema,
  timeZoneSchema,
} from '../common/validation/date.schema';
import { FieldErrorCode } from '../common/validation/field-errors';

function addSemanticIssue(
  ctx: z.RefinementCtx,
  field: string,
  fieldErrorCode: (typeof FieldErrorCode)[keyof typeof FieldErrorCode],
) {
  ctx.addIssue({
    code: z.ZodIssueCode.custom,
    path: [field],
    message: 'Invalid goal plan field',
    params: { fieldErrorCode },
  });
}

export const goalsQuerySchema = z.object({
  date: calendarDateSchema.optional(),
  tz: timeZoneSchema.optional(),
});

export type GoalsQueryDto = z.infer<typeof goalsQuerySchema>;

/**
 * Onboarding preview input. It mirrors the profile-create payload so the
 * onboarding can calculate a plan before any profile row exists.
 */
export const previewDraftSchema = z.object({
  weight: z.number().finite().min(20).max(400),
  height: z.number().int().min(50).max(300),
  age: z.number().int().min(1).max(120),
  gender: z.enum(['male', 'female']),
  goal: z.enum(['lose', 'gain', 'maintain']),
  activityLevel: z.enum(['low', 'medium', 'high']),
  timeZone: timeZoneSchema.optional(),
  targetWeightKg: z.number().finite().min(20).max(400).nullable().optional(),
  targetWeightMinKg: z.number().finite().min(20).max(400).nullable().optional(),
  targetWeightMaxKg: z.number().finite().min(20).max(400).nullable().optional(),
  weeklyRateKg: z.number().finite().positive().max(2).nullable().optional(),
  targetDate: calendarDateSchema.nullable().optional(),
  goalStartedAt: z.coerce.date().optional(),
});

export type GoalsPreviewDraftDto = z.infer<typeof previewDraftSchema>;

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
      addSemanticIssue(ctx, 'goal', FieldErrorCode.goalRequiredForNewCycle);
    }
    if (value.action === 'adjust_tempo') {
      if (
        value.weeklyRateKg === undefined &&
        value.targetDate === undefined &&
        value.targetWeightKg === undefined
      ) {
        addSemanticIssue(ctx, 'action', FieldErrorCode.tempoAdjustmentRequired);
      }
    }
    if (value.targetDate != null) {
      const today = new Date().toISOString().slice(0, 10);
      if (value.targetDate < today) {
        addSemanticIssue(ctx, 'targetDate', FieldErrorCode.targetDateInPast);
      }
    }
  });

export type NewCycleDto = z.infer<typeof newCycleSchema>;
