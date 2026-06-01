import { z } from 'zod';
export const rangeQuerySchema = z.object({
  from: z.string().min(1),
  to: z.string().min(1),
});
export type RangeQueryDto = z.infer<typeof rangeQuerySchema>;