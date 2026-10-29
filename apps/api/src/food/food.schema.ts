import { z } from 'zod';
import { calendarDateSchema } from '../common/validation/date.schema';
import { roundNutrition } from '../common/nutrition/precision';

export const dateString = calendarDateSchema;

const nutritionNumber = (max: number) =>
  z.number().finite().min(0).max(max).transform(roundNutrition);

const portionNumber = z
  .number()
  .finite()
  .min(0)
  .max(10_000)
  .transform(roundNutrition);

// ── Food Entry (daily diary) ──────────────────────────────────────

export const createFoodEntrySchema = z.object({
  name: z.string().min(1).max(120),

  foodId: z.string().uuid().optional(),
  grams: portionNumber.optional(),

  calories: nutritionNumber(5000),
  protein: nutritionNumber(1000).optional(),
  fat: nutritionNumber(1000).optional(),
  carbs: nutritionNumber(1000).optional(),

  unit: z.string().max(10).optional(),

  brand: z.string().max(200).optional(),
  imageUrl: z.string().max(500).optional(),
  // In POST, an omitted key and null both mean "no category"; the field is
  // encoded explicitly so the client never has to stay silent to say so.
  categoryName: z.string().max(100).nullable().optional(),
  barcode: z.string().max(50).optional(),
  servingGrams: portionNumber.optional(),

  date: dateString.optional(),
});

export const updateFoodEntrySchema = createFoodEntrySchema.partial().extend({
  // In PATCH, omission means "leave unchanged" while null explicitly
  // detaches a user-owned food from its category.
  categoryName: z.string().max(100).nullable().optional(),
});

export type CreateFoodEntryDto = z.infer<typeof createFoodEntrySchema>;
export type UpdateFoodEntryDto = z.infer<typeof updateFoodEntrySchema>;

export const optionalDateQuerySchema = z.object({
  date: dateString.optional(),
});
export const requiredDateQuerySchema = z.object({ date: dateString });
export type OptionalDateQueryDto = z.infer<typeof optionalDateQuerySchema>;
export type RequiredDateQueryDto = z.infer<typeof requiredDateQuerySchema>;

// ── Food Categories ───────────────────────────────────────────────

export const createFoodCategorySchema = z.object({
  name: z.string().trim().min(1).max(100),
  icon: z.string().trim().max(50).optional(),
});

export type CreateFoodCategoryDto = z.infer<typeof createFoodCategorySchema>;

// A partial patch: an absent field is left untouched, `null` clears an icon.
export const updateFoodCategorySchema = createFoodCategorySchema
  .partial()
  .extend({
    icon: z.string().trim().max(50).nullable().optional(),
  });

export type UpdateFoodCategoryDto = z.infer<typeof updateFoodCategorySchema>;

// ── Food Catalog ──────────────────────────────────────────────────

export const createFoodSchema = z.object({
  name: z.string().min(1).max(255),
  categoryId: z.string().uuid().optional(),
  caloriesPer100g: nutritionNumber(1000),
  proteinPer100g: nutritionNumber(100).optional(),
  fatPer100g: nutritionNumber(100).optional(),
  carbsPer100g: nutritionNumber(100).optional(),
  barcode: z.string().max(50).optional(),
  imageUrl: z.string().max(500).optional(),
  servings: z
    .array(
      z.object({
        name: z.string().min(1).max(100),
        grams: portionNumber,
      }),
    )
    .optional(),
});

export type CreateFoodDto = z.infer<typeof createFoodSchema>;

// ── Food Servings (portions of a product) ───────────────────────

// A personal portion on top of the catalog ones. Stricter than the
// servings embedded in createFoodSchema: a 0 g portion is useless.
export const createFoodServingSchema = z.object({
  name: z.string().trim().min(1).max(100),
  grams: portionNumber.refine((value) => value > 0),
});

// Omission means "leave unchanged".
export const updateFoodServingSchema = createFoodServingSchema.partial();

export type CreateFoodServingDto = z.infer<typeof createFoodServingSchema>;
export type UpdateFoodServingDto = z.infer<typeof updateFoodServingSchema>;

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
  grams: portionNumber.nullable(),
  calories: nutritionNumber(5000).nullable(),
  protein: nutritionNumber(1000).nullable(),
  fat: nutritionNumber(1000).nullable(),
  carbs: nutritionNumber(1000).nullable(),
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
  // How many identical containers this object stands for. The model reports
  // one object with containers: 2 instead of repeating the same volume, which
  // is the only reliable way to tell two bottles from one bottle seen twice.
  containers: z.number().int().min(1).max(8).optional(),
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
