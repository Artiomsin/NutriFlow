import { z } from 'zod';

const dateRegex = /^\d{4}-\d{2}-\d{2}$/;
const isoRegex = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$/;

export const syncWorkoutSchema = z.object({
  healthKitWorkoutId: z.string().min(1).max(64),
  type: z.string().min(1).max(50),
  startDate: z.string().regex(isoRegex),
  endDate: z.string().regex(isoRegex),
  durationSeconds: z.number().min(0),
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
});

export const syncWorkoutsSchema = z.object({
  workouts: z.array(syncWorkoutSchema).min(1).max(200),
});

export const deleteMissingSchema = z.object({
  startDate: z.string().regex(isoRegex),
  healthKitWorkoutIds: z.array(z.string().min(1).max(64)).min(0).max(500),
});

export const historyQuerySchema = z.object({
  from: z.string().regex(dateRegex).optional(),
  to: z.string().regex(dateRegex).optional(),
  limit: z.coerce.number().int().min(1).max(200).default(200),
  offset: z.coerce.number().int().min(0).default(0),
});

export type SyncWorkoutDto = z.infer<typeof syncWorkoutSchema>;
export type SyncWorkoutsDto = z.infer<typeof syncWorkoutsSchema>;
export type HistoryQueryDto = z.infer<typeof historyQuerySchema>;
export type DeleteMissingDto = z.infer<typeof deleteMissingSchema>;