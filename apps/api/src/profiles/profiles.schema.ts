import { z } from 'zod';
import {
  FieldErrorCode,
  type FieldErrorCodeValue,
} from '../common/validation/field-errors';

const timeZoneSchema = z
  .string()
  .min(1)
  .max(64)
  .refine((value) => {
    try {
      Intl.DateTimeFormat(undefined, { timeZone: value });
      return true;
    } catch {
      return false;
    }
  }, 'Invalid IANA time zone');

export const preferredUnitsSchema = z.object({
  weight: z.enum(['metric', 'imperial']).default('metric'),
  volume: z.enum(['metric', 'imperial']).default('metric'),
  energy: z.enum(['kcal', 'kj']).default('kcal'),
});

const calendarDateSchema = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, 'date must be YYYY-MM-DD')
  .refine((value) => {
    const parsed = new Date(`${value}T00:00:00.000Z`);
    return (
      !Number.isNaN(parsed.getTime()) &&
      parsed.toISOString().slice(0, 10) === value
    );
  }, 'date must be a valid calendar date');

const targetWeightSchema = z
  .number()
  .finite()
  .min(20)
  .max(400)
  .nullable()
  .optional();
const targetWeightMinSchema = z
  .number()
  .finite()
  .min(20)
  .max(400)
  .nullable()
  .optional();
const targetWeightMaxSchema = z
  .number()
  .finite()
  .min(20)
  .max(400)
  .nullable()
  .optional();
const weeklyRateSchema = z
  .number()
  .finite()
  .positive()
  .max(2)
  .nullable()
  .optional();

function isPastCalendarDate(dateStr: string): boolean {
  const today = new Date().toISOString().slice(0, 10);
  return dateStr < today;
}

function addSemanticIssue(
  ctx: z.RefinementCtx,
  field: string,
  fieldErrorCode: FieldErrorCodeValue,
) {
  ctx.addIssue({
    code: z.ZodIssueCode.custom,
    path: [field],
    message: 'Invalid goal plan field',
    params: { fieldErrorCode },
  });
}

function validateTargetSemantics(
  value: {
    goal?: 'lose' | 'gain' | 'maintain';
    weight?: number | null;
    targetWeightKg?: number | null;
    targetWeightMinKg?: number | null;
    targetWeightMaxKg?: number | null;
    weeklyRateKg?: number | null;
    targetDate?: string | null;
  },
  ctx: z.RefinementCtx,
) {
  if (value.weeklyRateKg != null && value.weeklyRateKg <= 0) {
    addSemanticIssue(
      ctx,
      'weeklyRateKg',
      FieldErrorCode.weeklyRateMustBePositive,
    );
  }

  if (value.targetDate != null && isPastCalendarDate(value.targetDate)) {
    addSemanticIssue(ctx, 'targetDate', FieldErrorCode.targetDateInPast);
  }

  const goal = value.goal;
  const targetWeightKg = value.targetWeightKg;
  const currentWeight = value.weight;

  if (goal === 'lose') {
    if (
      targetWeightKg != null &&
      currentWeight != null &&
      targetWeightKg >= currentWeight
    ) {
      addSemanticIssue(
        ctx,
        'targetWeightKg',
        FieldErrorCode.targetWeightMustBeLowerThanCurrent,
      );
    }
  }

  if (goal === 'gain') {
    if (
      targetWeightKg != null &&
      currentWeight != null &&
      targetWeightKg <= currentWeight
    ) {
      addSemanticIssue(
        ctx,
        'targetWeightKg',
        FieldErrorCode.targetWeightMustBeHigherThanCurrent,
      );
    }
  }

  const minKg = value.targetWeightMinKg;
  const maxKg = value.targetWeightMaxKg;
  const hasMin = minKg != null;
  const hasMax = maxKg != null;
  if (hasMin !== hasMax) {
    addSemanticIssue(
      ctx,
      hasMin ? 'targetWeightMaxKg' : 'targetWeightMinKg',
      FieldErrorCode.maintainRangePairRequired,
    );
  }
  if (hasMin && hasMax) {
    if (minKg! >= maxKg!) {
      addSemanticIssue(
        ctx,
        'targetWeightMaxKg',
        FieldErrorCode.maintainRangeOrderInvalid,
      );
    } else {
      const width = maxKg! - minKg!;
      if (width < 0.5 || width > 10) {
        addSemanticIssue(
          ctx,
          'targetWeightMaxKg',
          FieldErrorCode.maintainRangeWidthOutOfRange,
        );
      }
    }
  }

  if (goal === 'maintain') {
    // Prefer explicit range for maintain; targetWeightKg is optional anchor for backward compat.
    if (hasMin && hasMax) {
      if (currentWeight != null) {
        if (maxKg! < currentWeight - 15 || minKg! > currentWeight + 15) {
          addSemanticIssue(
            ctx,
            'targetWeightMinKg',
            FieldErrorCode.maintainRangeTooFarFromCurrent,
          );
        }
      }
      if (targetWeightKg != null) {
        if (targetWeightKg < minKg! || targetWeightKg > maxKg!) {
          addSemanticIssue(
            ctx,
            'targetWeightKg',
            FieldErrorCode.targetWeightOutsideMaintainRange,
          );
        }
      }
    } else if (targetWeightKg != null && currentWeight != null) {
      const diff = Math.abs(targetWeightKg - currentWeight);
      if (diff > 10) {
        addSemanticIssue(
          ctx,
          'targetWeightKg',
          FieldErrorCode.targetWeightTooFarFromCurrent,
        );
      }
    }
  } else if (hasMin || hasMax) {
    addSemanticIssue(
      ctx,
      'targetWeightMinKg',
      FieldErrorCode.maintainRangeNotAllowed,
    );
  }

  if (
    value.targetDate != null &&
    targetWeightKg == null &&
    goal !== 'maintain'
  ) {
    addSemanticIssue(
      ctx,
      'targetWeightKg',
      FieldErrorCode.targetWeightRequiredForDate,
    );
  }
}

export const createProfileSchema = z
  .object({
    weight: z.number().finite().min(20).max(400),
    height: z.number().int().min(50).max(300),
    age: z.number().int().min(1).max(120),
    gender: z.enum(['male', 'female']),
    goal: z.enum(['lose', 'gain', 'maintain']),
    activityLevel: z.enum(['low', 'medium', 'high']),
    timeZone: timeZoneSchema.optional(),
    preferredUnits: preferredUnitsSchema.optional(),
    targetWeightKg: targetWeightSchema,
    targetWeightMinKg: targetWeightMinSchema,
    targetWeightMaxKg: targetWeightMaxSchema,
    weeklyRateKg: weeklyRateSchema,
    targetDate: calendarDateSchema.nullable().optional(),
    goalStartedAt: z.coerce.date().optional(),
  })
  .superRefine((value, ctx) => {
    validateTargetSemantics(
      {
        goal: value.goal,
        weight: value.weight,
        targetWeightKg: value.targetWeightKg,
        targetWeightMinKg: value.targetWeightMinKg,
        targetWeightMaxKg: value.targetWeightMaxKg,
        weeklyRateKg: value.weeklyRateKg,
        targetDate: value.targetDate,
      },
      ctx,
    );
  });

export const updateProfileSchema = z
  .object({
    height: z.number().int().min(50).max(300).optional(),
    age: z.number().int().min(1).max(120).optional(),
    gender: z.enum(['male', 'female']).optional(),
    goal: z.enum(['lose', 'gain', 'maintain']).optional(),
    activityLevel: z.enum(['low', 'medium', 'high']).optional(),
    timeZone: timeZoneSchema.optional(),
    preferredUnits: preferredUnitsSchema.optional(),
    targetWeightKg: targetWeightSchema,
    targetWeightMinKg: targetWeightMinSchema,
    targetWeightMaxKg: targetWeightMaxSchema,
    weeklyRateKg: weeklyRateSchema,
    targetDate: calendarDateSchema.nullable().optional(),
    goalStartedAt: z.coerce.date().nullable().optional(),
  })
  .superRefine((value, ctx) => {
    // Weight is not updatable here; merged semantic validation happens in service.
    if (value.weeklyRateKg != null && value.weeklyRateKg <= 0) {
      addSemanticIssue(
        ctx,
        'weeklyRateKg',
        FieldErrorCode.weeklyRateMustBePositive,
      );
    }
    if (value.targetDate != null && isPastCalendarDate(value.targetDate)) {
      addSemanticIssue(ctx, 'targetDate', FieldErrorCode.targetDateInPast);
    }
  });

export const updateTimeZoneSchema = z.object({ timeZone: timeZoneSchema });

export type CreateProfileDto = z.infer<typeof createProfileSchema>;
export type UpdateProfileDto = z.infer<typeof updateProfileSchema>;
export type PreferredUnitsDto = z.infer<typeof preferredUnitsSchema>;
export type UpdateTimeZoneDto = z.infer<typeof updateTimeZoneSchema>;
