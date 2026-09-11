ALTER TABLE "app"."user_workouts" ADD COLUMN "avg_speed_mps" numeric(10, 2);--> statement-breakpoint
ALTER TABLE "app"."user_workouts" ADD COLUMN "max_speed_mps" numeric(10, 2);--> statement-breakpoint
ALTER TABLE "app"."user_workouts" ADD COLUMN "avg_cadence" numeric(10, 2);--> statement-breakpoint
ALTER TABLE "app"."user_workouts" ADD COLUMN "max_cadence" numeric(10, 2);--> statement-breakpoint
ALTER TABLE "app"."user_workouts" ADD COLUMN "avg_power_watts" numeric(10, 2);--> statement-breakpoint
ALTER TABLE "app"."user_workouts" ADD COLUMN "max_power_watts" numeric(10, 2);--> statement-breakpoint
ALTER TABLE "app"."user_workouts" ADD COLUMN "elevation_gain_meters" numeric(10, 2);--> statement-breakpoint
ALTER TABLE "app"."user_workouts" ADD COLUMN "details" jsonb DEFAULT '{}'::jsonb NOT NULL;