import { z } from 'zod';

export const dateString = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, 'date must be YYYY-MM-DD');

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
  // In POST, an omitted key and null both mean "no category"; the field is
  // encoded explicitly so the client never has to stay silent to say so.
  categoryName: z.string().max(100).nullable().optional(),
  barcode: z.string().max(50).optional(),
  servingGrams: z.number().int().nonnegative().max(10000).optional(),

  date: dateString.optional(),
});

export const updateFoodEntrySchema = createFoodEntrySchema.partial().extend({
  // In PATCH, omission means "leave unchanged" while null explicitly
  // detaches a user-owned food from its category.
  categoryName: z.string().max(100).nullable().optional(),
});

export type CreateFoodEntryDto = z.infer<typeof createFoodEntrySchema>;
export type UpdateFoodEntryDto = z.infer<typeof updateFoodEntrySchema>;

export const optionalDateQuerySchema = z.object({ date: dateString.optional() });
export const requiredDateQuerySchema = z.object({ date: dateString });
export type OptionalDateQueryDto = z.infer<typeof optionalDateQuerySchema>;
export type RequiredDateQueryDto = z.infer<typeof requiredDateQuerySchema>;

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
  q: z.string().trim().min(1).max(100),
  limit: z.coerce.number().int().min(1).max(50).optional().default(20),
  offset: z.coerce.number().int().min(0).max(500).optional().default(0),
});

export type SearchFoodQueryDto = z.infer<typeof searchFoodQuerySchema>;

export const foodAnalysisFoodItemSchema = z.object({
  kind: z.literal('food'),
  name: z.string().max(255).nullable(),
  category: z.string().max(100).nullish(),
  grams: z.number().int().nonnegative().nullable(),
  calories: z.number().nonnegative().nullable(),
  protein: z.number().nonnegative().nullable(),
  fat: z.number().nonnegative().nullable(),
  carbs: z.number().nonnegative().nullable(),
  unit: z.enum(['g', 'ml']).nullish(),
  imageUrl: z.string().max(500).nullish(),
  confidence: z.number().min(0).max(1).nullable(),
  foodId: z.string().uuid().nullish(),
  source: z.enum(['ai', 'catalog']).nullish(),
  aiCalories: z.number().nonnegative().nullish(),
  catalogCalories: z.number().nonnegative().nullish(),
});

export const foodAnalysisWaterItemSchema = z.object({
  kind: z.literal('water'),
  amountMl: z.number().int().min(50).max(2_000),
  confidence: z.number().min(0).max(1).nullable(),
});

export const foodAnalysisItemSchema = z.discriminatedUnion('kind', [
  foodAnalysisFoodItemSchema,
  foodAnalysisWaterItemSchema,
]);

export const foodAnalysisResponseSchema = z.array(foodAnalysisItemSchema);

export type FoodAnalysisFoodItem = z.infer<typeof foodAnalysisFoodItemSchema>;
export type FoodAnalysisWaterItem = z.infer<typeof foodAnalysisWaterItemSchema>;
export type FoodAnalysisItem = z.infer<typeof foodAnalysisItemSchema>;
export type FoodAnalysisResult = z.infer<typeof foodAnalysisResponseSchema>;
