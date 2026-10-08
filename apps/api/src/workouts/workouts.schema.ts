import { z } from 'zod';
import {
  calendarDateSchema,
  isoDateTimeSchema,
} from '../common/validation/date.schema';

export const syncWorkoutSchema = z.object({
  healthKitWorkoutId: z.string().min(1).max(64),
  type: z.string().min(1).max(50),
  startDate: isoDateTimeSchema,
  endDate: isoDateTimeSchema,
  localDate: calendarDateSchema,
  durationSeconds: z.number().min(0).max(86_400),
  caloriesBurned: z.number().min(0).optional(),
  distanceMeters: z.number().min(0).optional(),
  heartRateAvg: z.number().min(0).max(300).nullable().optional(),
  heartRateMax: z.number().min(0).max(300).nullable().optional(),
  heartRateMin: z.number().min(0).max(300).nullable().optional(),
  avgSpeedMps: z.number().min(0).nullable().optional(),
  maxSpeedMps: z.number().min(0).nullable().optional(),
  avgCadence: z.number().min(0).nullable().optional(),
  maxCadence: z.number().min(0).nullable().optional(),
  avgPowerWatts: z.number().min(0).nullable().optional(),
  maxPowerWatts: z.number().min(0).nullable().optional(),
  elevationGainMeters: z.number().min(0).nullable().optional(),
  steps: z.number().int().min(0).nullable().optional(),
  indoor: z.boolean().nullable().optional(),
  details: z.record(z.string(), z.unknown()).optional(),
}).refine((value) => new Date(value.endDate) > new Date(value.startDate), {
  message: 'endDate must be after startDate',
  path: ['endDate'],
});

export const syncWorkoutsSchema = z.object({
  workouts: z.array(syncWorkoutSchema).min(1).max(200),
});

export const deleteMissingSchema = z.object({
  startDate: isoDateTimeSchema,
  endDate: isoDateTimeSchema,
  healthKitWorkoutIds: z.array(z.string().min(1).max(64)).min(0).max(500),
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

export type SyncWorkoutDto = z.infer<typeof syncWorkoutSchema>;
export type SyncWorkoutsDto = z.infer<typeof syncWorkoutsSchema>;
export type HistoryQueryDto = z.infer<typeof historyQuerySchema>;
export type DeleteMissingDto = z.infer<typeof deleteMissingSchema>;
