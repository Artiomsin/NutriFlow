ALTER TABLE "app"."food_entries"
  ALTER COLUMN "grams" SET DATA TYPE numeric(10, 3) USING "grams"::numeric(10, 3);
--> statement-breakpoint
ALTER TABLE "app"."food_servings"
  ALTER COLUMN "grams" SET DATA TYPE numeric(10, 3) USING "grams"::numeric(10, 3);
