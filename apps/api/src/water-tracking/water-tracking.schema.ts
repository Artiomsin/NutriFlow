import { z } from 'zod';
import { calendarDateSchema } from '../common/validation/date.schema';

export const dateString = calendarDateSchema;

export const createWaterEntrySchema = z.object({
  amountMl: z.number().int().min(1).max(3000),
  date: dateString.optional(),
});

export type CreateWaterEntryDto = z.infer<typeof createWaterEntrySchema>;

export const optionalDateQuerySchema = z.object({ date: dateString.optional() });
export const requiredDateQuerySchema = z.object({ date: dateString });
export type OptionalDateQueryDto = z.infer<typeof optionalDateQuerySchema>;
export type RequiredDateQueryDto = z.infer<typeof requiredDateQuerySchema>;
