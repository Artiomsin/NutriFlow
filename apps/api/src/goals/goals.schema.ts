import { z } from 'zod';


export const updateGoalsSchema = z.object({
  dailyCaloriesGoal: z.number().int().positive().nullable().optional(),
  dailyProteinGoal: z.number().int().positive().nullable().optional(),
  dailyFatGoal: z.number().int().positive().nullable().optional(),
  dailyCarbsGoal: z.number().int().positive().nullable().optional(),
  dailyWaterGoal: z.number().int().positive().nullable().optional(),
});
export type UpdateGoalsDto = z.infer<typeof updateGoalsSchema>;