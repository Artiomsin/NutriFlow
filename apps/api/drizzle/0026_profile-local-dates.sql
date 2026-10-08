ALTER TABLE "app"."user_profiles" ADD COLUMN "time_zone" varchar(64) DEFAULT 'UTC' NOT NULL;--> statement-breakpoint
ALTER TABLE "app"."user_workouts" ADD COLUMN "local_date" date;--> statement-breakpoint
UPDATE "app"."user_workouts" SET "local_date" = "start_date"::date WHERE "local_date" IS NULL;--> statement-breakpoint
ALTER TABLE "app"."user_workouts" ALTER COLUMN "local_date" SET NOT NULL;--> statement-breakpoint
ALTER TABLE "app"."user_sleep" ADD COLUMN "local_date" date;--> statement-breakpoint
UPDATE "app"."user_sleep" SET "local_date" = "start_date"::date WHERE "local_date" IS NULL;--> statement-breakpoint
ALTER TABLE "app"."user_sleep" ALTER COLUMN "local_date" SET NOT NULL;
