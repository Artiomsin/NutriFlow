import { z } from 'zod';

export const preferredUnitsSchema = z.object({
  weight: z.enum(['metric', 'imperial']).default('metric'),
  volume: z.enum(['metric', 'imperial']).default('metric'),
  energy: z.enum(['kcal', 'kj']).default('kcal'),
});

export const createProfileSchema = z.object({
  weight: z.number().positive().optional(),
  height: z.number().int().positive().optional(),
  age: z.number().int().min(1).max(120).optional(),
  gender: z.enum(['male', 'female']).optional(),
  goal: z.enum(['lose', 'gain', 'maintain']).optional(),
  activityLevel: z.enum(['low', 'medium', 'high']).optional(),
  preferredUnits: preferredUnitsSchema.optional(),
});
export const updateProfileSchema = createProfileSchema.partial();

export type CreateProfileDto = z.infer<typeof createProfileSchema>;
export type UpdateProfileDto = z.infer<typeof updateProfileSchema>;
export type PreferredUnitsDto = z.infer<typeof preferredUnitsSchema>;
