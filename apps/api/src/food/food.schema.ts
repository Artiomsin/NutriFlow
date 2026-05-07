import { z } from 'zod';

export const createFoodEntrySchema = z.object({
  name: z.string().min(1).max(120),

  calories: z.number().int().nonnegative(),
  protein: z.number().int().nonnegative().optional(),
  fat: z.number().int().nonnegative().optional(),
  carbs: z.number().int().nonnegative().optional(),
});

export const updateFoodEntrySchema = createFoodEntrySchema.partial();

export type CreateFoodEntryDto = z.infer<typeof createFoodEntrySchema>;
export type UpdateFoodEntryDto = z.infer<typeof updateFoodEntrySchema>;