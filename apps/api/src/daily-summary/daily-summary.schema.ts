import { z } from 'zod';

export const dateQuerySchema = z.object({
  date: z.string().optional(),
});

export const rangeQuerySchema = z.object({
  from: z.string().min(1),
  to: z.string().min(1),
});

export type DateQueryDto = z.infer<typeof dateQuerySchema>;
export type RangeQueryDto = z.infer<typeof rangeQuerySchema>;