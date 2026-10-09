import { z } from 'zod';

export const dateStringSchema = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, 'Invalid date, expected YYYY-MM-DD')
  .refine((value) => {
    const parsed = new Date(`${value}T00:00:00.000Z`);
    return !Number.isNaN(parsed.getTime()) && parsed.toISOString().slice(0, 10) === value;
  }, 'Invalid calendar date');

export const createWeightLogSchema = z.object({
  date: dateStringSchema.optional(),
  weightKg: z.number().positive().min(20).max(400),
});

export const listWeightLogsSchema = z.object({
  from: dateStringSchema.optional(),
  to: dateStringSchema.optional(),
}).refine((value) => !value.from || !value.to || value.from <= value.to, {
  message: 'from must not be after to',
  path: ['to'],
});

export const weightLogDateParamSchema = z.object({
  date: dateStringSchema,
});

export type CreateWeightLogDto = z.infer<typeof createWeightLogSchema>;
export type ListWeightLogsDto = z.infer<typeof listWeightLogsSchema>;
export type WeightLogDateParamDto = z.infer<typeof weightLogDateParamSchema>;
