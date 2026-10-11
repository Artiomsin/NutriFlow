import { z } from 'zod';
import { calendarDateSchema } from '../common/validation/date.schema';

const dateString = calendarDateSchema;
const MAX_RANGE_DAYS = 366;

export const dateQuerySchema = z.object({
  date: dateString.optional(),
});

export const rangeQuerySchema = z
  .object({
    from: dateString,
    to: dateString,
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

export type DateQueryDto = z.infer<typeof dateQuerySchema>;
export type RangeQueryDto = z.infer<typeof rangeQuerySchema>;
