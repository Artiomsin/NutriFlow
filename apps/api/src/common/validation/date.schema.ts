import { z } from 'zod';

const calendarDatePattern = /^\d{4}-\d{2}-\d{2}$/;
const isoDateTimePattern = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$/;

export const calendarDateSchema = z
  .string()
  .regex(calendarDatePattern, 'date must be YYYY-MM-DD')
  .refine((value) => {
    const parsed = new Date(`${value}T00:00:00.000Z`);
    return !Number.isNaN(parsed.getTime()) && parsed.toISOString().slice(0, 10) === value;
  }, 'date must be a valid calendar date');

export const isoDateTimeSchema = z
  .string()
  .regex(isoDateTimePattern, 'date must be an ISO 8601 date-time with an offset')
  .refine((value) => !Number.isNaN(new Date(value).getTime()), 'date must be valid');
