import { z } from 'zod';

const dateRegex = /^\d{4}-\d{2}-\d{2}$/;

export const rangeQuerySchema = z.object({
  from: z.string().regex(dateRegex, 'from must be a valid date (YYYY-MM-DD)'),
  to: z.string().regex(dateRegex, 'to must be a valid date (YYYY-MM-DD)'),
});
export type RangeQueryDto = z.infer<typeof rangeQuerySchema>;