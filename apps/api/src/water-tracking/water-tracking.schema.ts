import { z } from 'zod';

export const dateString = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'date must be YYYY-MM-DD');

export const createWaterEntrySchema = z.object({
  amountMl: z.number().int().positive(),
  date: dateString.optional(),
});

export type CreateWaterEntryDto = z.infer<typeof createWaterEntrySchema>;

export const optionalDateQuerySchema = z.object({ date: dateString.optional() });
export const requiredDateQuerySchema = z.object({ date: dateString });
export type OptionalDateQueryDto = z.infer<typeof optionalDateQuerySchema>;
export type RequiredDateQueryDto = z.infer<typeof requiredDateQuerySchema>;
