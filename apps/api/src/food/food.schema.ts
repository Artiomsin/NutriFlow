import { z } from 'zod';

// ── Food Entry (daily diary) ──────────────────────────────────────

export const createFoodEntrySchema = z.object({
  name: z.string().min(1).max(120),

  foodId: z.string().uuid().optional(),
  grams: z.number().int().nonnegative().optional(),

  calories: z.number().int().nonnegative(),
  protein: z.number().int().nonnegative().optional(),
  fat: z.number().int().nonnegative().optional(),
  carbs: z.number().int().nonnegative().optional(),
});

export const updateFoodEntrySchema = createFoodEntrySchema.partial();

export type CreateFoodEntryDto = z.infer<typeof createFoodEntrySchema>;
export type UpdateFoodEntryDto = z.infer<typeof updateFoodEntrySchema>;

// ── Food Categories ───────────────────────────────────────────────

export const createFoodCategorySchema = z.object({
  name: z.string().min(1).max(100),
  icon: z.string().max(50).optional(),
});

export type CreateFoodCategoryDto = z.infer<typeof createFoodCategorySchema>;

// ── Food Catalog ──────────────────────────────────────────────────

export const createFoodSchema = z.object({
  name: z.string().min(1).max(255),
  categoryId: z.string().uuid().optional(),
  caloriesPer100g: z.number().nonnegative(),
  proteinPer100g: z.number().nonnegative().optional(),
  fatPer100g: z.number().nonnegative().optional(),
  carbsPer100g: z.number().nonnegative().optional(),
  barcode: z.string().max(50).optional(),
  imageUrl: z.string().max(500).optional(),
  servings: z
    .array(
      z.object({
        name: z.string().min(1).max(100),
        grams: z.number().int().nonnegative(),
      }),
    )
    .optional(),
});

export type CreateFoodDto = z.infer<typeof createFoodSchema>;

export const searchFoodQuerySchema = z.object({
  q: z.string().min(1).max(100),
  limit: z.coerce.number().int().min(1).max(50).optional().default(20),
});

export type SearchFoodQueryDto = z.infer<typeof searchFoodQuerySchema>;