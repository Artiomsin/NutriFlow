import { z } from 'zod';

// ── Food Entry (daily diary) ──────────────────────────────────────

export const createFoodEntrySchema = z.object({
  name: z.string().min(1).max(120),

  foodId: z.string().uuid().optional(),
  grams: z.number().int().min(0).max(10000).optional(),

  calories: z.number().int().min(0).max(5000),
  protein: z.number().int().min(0).max(1000).optional(),
  fat: z.number().int().min(0).max(1000).optional(),
  carbs: z.number().int().min(0).max(1000).optional(),

  unit: z.string().max(10).optional(),

  brand: z.string().max(200).optional(),
  imageUrl: z.string().max(500).optional(),
  categoryName: z.string().max(100).optional(),
  barcode: z.string().max(50).optional(),
  servingGrams: z.number().int().nonnegative().max(10000).optional(),

  date: z.string().optional(),
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

export const foodAnalysisItemSchema = z.object({
  name: z.string().max(255).nullable(),
  category: z.string().max(100).nullish(),
  grams: z.number().int().nonnegative().nullable(),
  calories: z.number().nonnegative().nullable(),
  protein: z.number().nonnegative().nullable(),
  fat: z.number().nonnegative().nullable(),
  carbs: z.number().nonnegative().nullable(),
  unit: z.string().max(10).nullish(),
  imageUrl: z.string().max(500).nullish(),
  confidence: z.number().min(0).max(1).nullable(),
  foodId: z.string().uuid().nullish(),
  source: z.enum(['ai', 'catalog']).nullish(),
  aiCalories: z.number().nonnegative().nullish(),
  catalogCalories: z.number().nonnegative().nullish(),
});

export const foodAnalysisResponseSchema = z.array(foodAnalysisItemSchema);

export type FoodAnalysisItem = z.infer<typeof foodAnalysisItemSchema>;
export type FoodAnalysisResult = z.infer<typeof foodAnalysisResponseSchema>;
