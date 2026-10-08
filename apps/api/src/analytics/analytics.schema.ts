import { z } from 'zod';
import { calendarDateSchema } from '../common/validation/date.schema';

export const rangeQuerySchema = z.object({
  from: calendarDateSchema,
  to: calendarDateSchema,
}).refine((value) => value.from <= value.to, {
  message: 'from must not be after to',
  path: ['to'],
});
export type RangeQueryDto = z.infer<typeof rangeQuerySchema>;
