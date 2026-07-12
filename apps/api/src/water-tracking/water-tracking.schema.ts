import { z } from 'zod';

export const createWaterEntrySchema = z.object({
  amountMl: z.number().int().positive(),
  date: z.string().optional(),
});

export type CreateWaterEntryDto = z.infer<typeof createWaterEntrySchema>;