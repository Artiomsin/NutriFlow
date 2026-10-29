ALTER TABLE "app"."foods"
  ALTER COLUMN "calories_per_100g" SET DATA TYPE numeric(10, 1) USING "calories_per_100g"::numeric(10, 1),
  ALTER COLUMN "protein_per_100g" SET DATA TYPE numeric(10, 1) USING "protein_per_100g"::numeric(10, 1),
  ALTER COLUMN "fat_per_100g" SET DATA TYPE numeric(10, 1) USING "fat_per_100g"::numeric(10, 1),
  ALTER COLUMN "carbs_per_100g" SET DATA TYPE numeric(10, 1) USING "carbs_per_100g"::numeric(10, 1);
--> statement-breakpoint
ALTER TABLE "app"."food_servings"
  ALTER COLUMN "grams" SET DATA TYPE numeric(10, 1) USING "grams"::numeric(10, 1);
--> statement-breakpoint
ALTER TABLE "app"."food_entries"
  ALTER COLUMN "grams" SET DATA TYPE numeric(10, 1) USING "grams"::numeric(10, 1),
  ALTER COLUMN "calories" SET DATA TYPE numeric(10, 1) USING "calories"::numeric(10, 1),
  ALTER COLUMN "protein" SET DATA TYPE numeric(10, 1) USING "protein"::numeric(10, 1),
  ALTER COLUMN "fat" SET DATA TYPE numeric(10, 1) USING "fat"::numeric(10, 1),
  ALTER COLUMN "carbs" SET DATA TYPE numeric(10, 1) USING "carbs"::numeric(10, 1);
--> statement-breakpoint
ALTER TABLE "app"."daily_summary"
  ALTER COLUMN "total_calories" SET DATA TYPE numeric(10, 1) USING "total_calories"::numeric(10, 1),
  ALTER COLUMN "total_protein" SET DATA TYPE numeric(10, 1) USING "total_protein"::numeric(10, 1),
  ALTER COLUMN "total_fat" SET DATA TYPE numeric(10, 1) USING "total_fat"::numeric(10, 1),
  ALTER COLUMN "total_carbs" SET DATA TYPE numeric(10, 1) USING "total_carbs"::numeric(10, 1);
--> statement-breakpoint
ALTER TABLE "app"."user_goals"
  ALTER COLUMN "daily_calories_goal" SET DATA TYPE numeric(10, 1) USING "daily_calories_goal"::numeric(10, 1),
  ALTER COLUMN "daily_protein_goal" SET DATA TYPE numeric(10, 1) USING "daily_protein_goal"::numeric(10, 1),
  ALTER COLUMN "daily_fat_goal" SET DATA TYPE numeric(10, 1) USING "daily_fat_goal"::numeric(10, 1),
  ALTER COLUMN "daily_carbs_goal" SET DATA TYPE numeric(10, 1) USING "daily_carbs_goal"::numeric(10, 1);
--> statement-breakpoint
ALTER TABLE "app"."goal_history"
  ALTER COLUMN "old_value" SET DATA TYPE numeric(10, 1) USING "old_value"::numeric(10, 1),
  ALTER COLUMN "new_value" SET DATA TYPE numeric(10, 1) USING "new_value"::numeric(10, 1);
