ALTER TABLE "app"."user_workouts" ADD COLUMN "heart_rate_avg" numeric(5, 1);--> statement-breakpoint
ALTER TABLE "app"."user_workouts" ADD COLUMN "heart_rate_max" numeric(5, 1);--> statement-breakpoint
ALTER TABLE "app"."user_workouts" ADD COLUMN "heart_rate_min" numeric(5, 1);--> statement-breakpoint
CREATE INDEX "user_workouts_user_start_idx" ON "app"."user_workouts" USING btree ("user_id","start_date");