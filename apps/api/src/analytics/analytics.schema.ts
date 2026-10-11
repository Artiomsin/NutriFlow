import { z } from 'zod';
import { calendarDateSchema } from '../common/validation/date.schema';

const MAX_RANGE_DAYS = 366;

export const rangeQuerySchema = z
  .object({
    from: calendarDateSchema,
    to: calendarDateSchema,
  })
  .refine((value) => value.from <= value.to, {
    message: 'from must not be after to',
    path: ['to'],
  })
  .refine(
    (value) => {
      const from = new Date(`${value.from}T00:00:00.000Z`);
      const to = new Date(`${value.to}T00:00:00.000Z`);
      return (to.getTime() - from.getTime()) / 86_400_000 < MAX_RANGE_DAYS;
    },
    {
      message: `range must not exceed ${MAX_RANGE_DAYS} days`,
      path: ['to'],
    },
  );
export type RangeQueryDto = z.infer<typeof rangeQuerySchema>;
