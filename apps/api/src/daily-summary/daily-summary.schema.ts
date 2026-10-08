import { z } from 'zod';

const dateString = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'date must be YYYY-MM-DD');

export const dateQuerySchema = z.object({
  date: dateString.optional(),
});

export const rangeQuerySchema = z.object({
  from: dateString,
  to: dateString,
});

export type DateQueryDto = z.infer<typeof dateQuerySchema>;
export type RangeQueryDto = z.infer<typeof rangeQuerySchema>;
