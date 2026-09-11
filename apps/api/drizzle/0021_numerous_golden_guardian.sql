ALTER TABLE "app"."daily_activity" DROP COLUMN "source";--> statement-breakpoint
ALTER TABLE "app"."user_workouts" DROP COLUMN "source";--> statement-breakpoint
ALTER TABLE "app"."user_sleep" DROP COLUMN "sources";--> statement-breakpoint
ALTER TABLE "app"."user_sleep" DROP COLUMN "night_metrics";--> statement-breakpoint
ALTER TABLE "app"."user_sleep" DROP COLUMN "source";