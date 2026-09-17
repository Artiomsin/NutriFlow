ALTER TABLE "app"."user_goals" ADD COLUMN "daily_steps_goal" integer;--> statement-breakpoint
ALTER TABLE "app"."user_goals" ADD COLUMN "daily_active_calories_goal" integer;--> statement-breakpoint
ALTER TABLE "app"."user_goals" ADD COLUMN "weekly_workouts_goal" integer;--> statement-breakpoint
ALTER TABLE "app"."user_goals" ADD COLUMN "weekly_workout_minutes_goal" integer;--> statement-breakpoint
ALTER TABLE "app"."user_goals" ADD COLUMN "nightly_sleep_min_minutes" integer;--> statement-breakpoint
ALTER TABLE "app"."user_goals" ADD COLUMN "nightly_sleep_max_minutes" integer;