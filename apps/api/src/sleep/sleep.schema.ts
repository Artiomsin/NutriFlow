import { z } from 'zod';
import {
  calendarDateSchema,
  isoDateTimeSchema,
} from '../common/validation/date.schema';

export const syncSleepEntrySchema = z.object({
  startDate: isoDateTimeSchema,
  endDate: isoDateTimeSchema,
  localDate: calendarDateSchema,
  timeInBedSeconds: z.number().min(0).nullable().optional(),
  asleepSeconds: z.number().min(0).nullable().optional(),
  awakeSeconds: z.number().min(0).nullable().optional(),
  coreSeconds: z.number().min(0).nullable().optional(),
  deepSeconds: z.number().min(0).nullable().optional(),
  remSeconds: z.number().min(0).nullable().optional(),
  unspecifiedSeconds: z.number().min(0).nullable().optional(),
  awakenings: z.number().int().min(0).nullable().optional(),
  onsetLatencySeconds: z.number().min(0).nullable().optional(),
  efficiency: z.number().min(0).max(100).nullable().optional(),
  segmentCount: z.number().int().min(0).nullable().optional(),
  heartRateAvg: z.number().min(0).max(300).nullable().optional(),
}).refine((value) => new Date(value.endDate) > new Date(value.startDate), {
  message: 'endDate must be after startDate',
  path: ['endDate'],
});

export const syncSleepSchema = z.object({
  nights: z.array(syncSleepEntrySchema).min(1).max(50),
});

export const deleteMissingSchema = z.object({
  startDate: isoDateTimeSchema,
  endDate: isoDateTimeSchema,
  // These are the nights HealthKit still has in the reconciliation window.
  // Rows absent from this list are the only rows eligible for deletion.
  keptStartDates: z.array(isoDateTimeSchema).min(0).max(500),
}).refine((value) => new Date(value.endDate) >= new Date(value.startDate), {
  message: 'endDate must not be before startDate',
  path: ['endDate'],
});

export const historyQuerySchema = z.object({
  from: calendarDateSchema.optional(),
  to: calendarDateSchema.optional(),
  limit: z.coerce.number().int().min(1).max(200).default(200),
  offset: z.coerce.number().int().min(0).default(0),
}).refine((value) => !value.from || !value.to || value.from <= value.to, {
  message: 'from must not be after to',
  path: ['to'],
});

export type SyncSleepEntryDto = z.infer<typeof syncSleepEntrySchema>;
export type SyncSleepDto = z.infer<typeof syncSleepSchema>;
export type HistoryQueryDto = z.infer<typeof historyQuerySchema>;
export type DeleteMissingDto = z.infer<typeof deleteMissingSchema>;
