ALTER TABLE "app"."daily_activity"
  ALTER COLUMN "active_calories" SET DATA TYPE numeric(10, 1) USING "active_calories"::numeric(10, 1),
  ALTER COLUMN "basal_calories" SET DATA TYPE numeric(10, 1) USING "basal_calories"::numeric(10, 1);
