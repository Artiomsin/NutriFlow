import { z } from 'zod';

export const dateStringSchema = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, 'Invalid date, expected YYYY-MM-DD');

export const createWeightLogSchema = z.object({
  date: dateStringSchema.optional(),
  weightKg: z.number().positive().min(20).max(400),
});

export const listWeightLogsSchema = z.object({
  from: dateStringSchema.optional(),
  to: dateStringSchema.optional(),
});

export type CreateWeightLogDto = z.infer<typeof createWeightLogSchema>;
export type ListWeightLogsDto = z.infer<typeof listWeightLogsSchema>;