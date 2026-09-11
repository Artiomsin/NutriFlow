import { z } from 'zod';

const dateRegex = /^\d{4}-\d{2}-\d{2}$/;
const isoRegex = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$/;

export const syncSleepEntrySchema = z.object({
  startDate: z.string().regex(isoRegex),
  endDate: z.string().regex(isoRegex),
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
});

export const syncSleepSchema = z.object({
  nights: z.array(syncSleepEntrySchema).min(1).max(50),
});

export const deleteMissingSchema = z.object({
  startDate: z.string().regex(isoRegex),
  startDates: z.array(z.string().regex(isoRegex)).min(0).max(500),
});

export const historyQuerySchema = z.object({
  from: z.string().regex(dateRegex).optional(),
  to: z.string().regex(dateRegex).optional(),
  limit: z.coerce.number().int().min(1).max(200).default(200),
  offset: z.coerce.number().int().min(0).default(0),
});

export type SyncSleepEntryDto = z.infer<typeof syncSleepEntrySchema>;
export type SyncSleepDto = z.infer<typeof syncSleepSchema>;
export type HistoryQueryDto = z.infer<typeof historyQuerySchema>;
export type DeleteMissingDto = z.infer<typeof deleteMissingSchema>;