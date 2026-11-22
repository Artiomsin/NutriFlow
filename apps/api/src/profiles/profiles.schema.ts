import { z } from 'zod';

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
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['weeklyRateKg'],
      message: 'weeklyRateKg must be positive',
    });
  }

  if (value.targetDate != null && isPastCalendarDate(value.targetDate)) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['targetDate'],
      message: 'targetDate must not be in the past',
    });
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
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['targetWeightKg'],
        message:
          'targetWeightKg must be less than current weight for lose goal',
      });
    }
  }

  if (goal === 'gain') {
    if (
      targetWeightKg != null &&
      currentWeight != null &&
      targetWeightKg <= currentWeight
    ) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['targetWeightKg'],
        message:
          'targetWeightKg must be greater than current weight for gain goal',
      });
    }
  }

  const minKg = value.targetWeightMinKg;
  const maxKg = value.targetWeightMaxKg;
  const hasMin = minKg != null;
  const hasMax = maxKg != null;
  if (hasMin !== hasMax) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: hasMin ? ['targetWeightMaxKg'] : ['targetWeightMinKg'],
      message:
        'targetWeightMinKg and targetWeightMaxKg must be provided together',
    });
  }
  if (hasMin && hasMax) {
    if (minKg! >= maxKg!) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['targetWeightMaxKg'],
        message: 'targetWeightMaxKg must be greater than targetWeightMinKg',
      });
    } else {
      const width = maxKg! - minKg!;
      if (width < 0.5 || width > 10) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['targetWeightMaxKg'],
          message: 'Maintain range width should be between 0.5 and 10 kg',
        });
      }
    }
  }

  if (goal === 'maintain') {
    // Prefer explicit range for maintain; targetWeightKg is optional anchor for backward compat.
    if (hasMin && hasMax) {
      if (currentWeight != null) {
        if (maxKg! < currentWeight - 15 || minKg! > currentWeight + 15) {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            path: ['targetWeightMinKg'],
            message:
              'Maintain range should be reasonably close to current weight',
          });
        }
      }
      if (targetWeightKg != null) {
        if (targetWeightKg < minKg! || targetWeightKg > maxKg!) {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            path: ['targetWeightKg'],
            message:
              'targetWeightKg must be within maintain range when range is provided',
          });
        }
      }
    } else if (targetWeightKg != null && currentWeight != null) {
      const diff = Math.abs(targetWeightKg - currentWeight);
      if (diff > 10) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['targetWeightKg'],
          message:
            'For maintain goal, targetWeightKg should be within 10kg of current weight (maintenance range anchor)',
        });
      }
    }
  } else if (hasMin || hasMax) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['targetWeightMinKg'],
      message: 'Maintain range is only supported for maintain goal',
    });
  }

  if (
    value.targetDate != null &&
    targetWeightKg == null &&
    goal !== 'maintain'
  ) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['targetWeightKg'],
      message: 'targetWeightKg is required when targetDate is set',
    });
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
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['weeklyRateKg'],
        message: 'weeklyRateKg must be positive',
      });
    }
    if (value.targetDate != null && isPastCalendarDate(value.targetDate)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['targetDate'],
        message: 'targetDate must not be in the past',
      });
    }
  });

export const updateTimeZoneSchema = z.object({ timeZone: timeZoneSchema });

export type CreateProfileDto = z.infer<typeof createProfileSchema>;
export type UpdateProfileDto = z.infer<typeof updateProfileSchema>;
export type PreferredUnitsDto = z.infer<typeof preferredUnitsSchema>;
export type UpdateTimeZoneDto = z.infer<typeof updateTimeZoneSchema>;
