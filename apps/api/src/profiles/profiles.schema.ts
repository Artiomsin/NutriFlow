import { z } from 'zod';

const timeZoneSchema = z.string().min(1).max(64).refine(
  (value) => {
    try {
      Intl.DateTimeFormat(undefined, { timeZone: value });
      return true;
    } catch {
      return false;
    }
  },
  'Invalid IANA time zone',
);

export const preferredUnitsSchema = z.object({
  weight: z.enum(['metric', 'imperial']).default('metric'),
  volume: z.enum(['metric', 'imperial']).default('metric'),
  energy: z.enum(['kcal', 'kj']).default('kcal'),
});

export const createProfileSchema = z.object({
  weight: z.number().positive(),
  height: z.number().int().positive(),
  age: z.number().int().min(1).max(120),
  gender: z.enum(['male', 'female']),
  goal: z.enum(['lose', 'gain', 'maintain']),
  activityLevel: z.enum(['low', 'medium', 'high']),
  timeZone: timeZoneSchema.optional(),
  preferredUnits: preferredUnitsSchema.optional(),
});
export const updateProfileSchema = z.object({
  height: z.number().int().positive().optional(),
  age: z.number().int().min(1).max(120).optional(),
  gender: z.enum(['male', 'female']).optional(),
  goal: z.enum(['lose', 'gain', 'maintain']).optional(),
  activityLevel: z.enum(['low', 'medium', 'high']).optional(),
  timeZone: timeZoneSchema.optional(),
  preferredUnits: preferredUnitsSchema.optional(),
});
export const updateTimeZoneSchema = z.object({ timeZone: timeZoneSchema });

export type CreateProfileDto = z.infer<typeof createProfileSchema>;
export type UpdateProfileDto = z.infer<typeof updateProfileSchema>;
export type PreferredUnitsDto = z.infer<typeof preferredUnitsSchema>;
export type UpdateTimeZoneDto = z.infer<typeof updateTimeZoneSchema>;
