-- Existing entries created before entry_date was required need a deterministic
-- date before the constraint can be added. created_at is the closest available
-- source of truth and preserves the database's calendar date.
UPDATE "app"."water_entries"
SET "entry_date" = "created_at"::date
WHERE "entry_date" IS NULL;--> statement-breakpoint
UPDATE "app"."food_entries"
SET "entry_date" = "created_at"::date
WHERE "entry_date" IS NULL;--> statement-breakpoint
ALTER TABLE "app"."water_entries" ALTER COLUMN "entry_date" SET NOT NULL;--> statement-breakpoint
ALTER TABLE "app"."food_entries" ALTER COLUMN "entry_date" SET NOT NULL;
