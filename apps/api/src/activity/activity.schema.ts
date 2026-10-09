import { z } from 'zod';
import { calendarDateSchema } from '../common/validation/date.schema';

export const syncEntrySchema = z.object({
  date: calendarDateSchema,
  steps: z.number().int().min(0).optional(),
  activeCalories: z.number().int().min(0).optional(),
  basalCalories: z.number().int().min(0).optional(),
  distanceMeters: z.number().min(0).optional(),
});

export const syncActivitySchema = z.object({
  entries: z.array(syncEntrySchema).min(1).max(31),
});

export const rangeQuerySchema = z.object({
  from: calendarDateSchema,
  to: calendarDateSchema,
}).refine((value) => value.from <= value.to, {
  message: 'from must not be after to',
  path: ['to'],
});

export const optionalDateQuerySchema = z.object({
  date: calendarDateSchema.optional(),
});

export type SyncActivityDto = z.infer<typeof syncActivitySchema>;
export type RangeQueryDto = z.infer<typeof rangeQuerySchema>;
export type OptionalDateQueryDto = z.infer<typeof optionalDateQuerySchema>;
