import { z } from 'zod';

const dateRegex = /^\d{4}-\d{2}-\d{2}$/;

export const syncEntrySchema = z.object({
  date: z.string().regex(dateRegex),
  steps: z.number().int().min(0).optional(),
  activeCalories: z.number().int().min(0).optional(),
  distanceMeters: z.number().min(0).optional(),
});

export const syncActivitySchema = z.object({
  entries: z.array(syncEntrySchema).min(1).max(31),
});

export const rangeQuerySchema = z.object({
  from: z.string().regex(dateRegex),
  to: z.string().regex(dateRegex),
});

export type SyncActivityDto = z.infer<typeof syncActivitySchema>;
export type RangeQueryDto = z.infer<typeof rangeQuerySchema>;