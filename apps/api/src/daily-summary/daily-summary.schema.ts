import { z } from 'zod';
import { calendarDateSchema } from '../common/validation/date.schema';

const dateString = calendarDateSchema;

export const dateQuerySchema = z.object({
  date: dateString.optional(),
});

export const rangeQuerySchema = z.object({
  from: dateString,
  to: dateString,
}).refine((value) => value.from <= value.to, {
  message: 'from must not be after to',
  path: ['to'],
});

export type DateQueryDto = z.infer<typeof dateQuerySchema>;
export type RangeQueryDto = z.infer<typeof rangeQuerySchema>;
