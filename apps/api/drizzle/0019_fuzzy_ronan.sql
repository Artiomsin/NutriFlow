ALTER TABLE "app"."user_profiles" ADD COLUMN "target_weight_kg" numeric(5, 2);--> statement-breakpoint
ALTER TABLE "app"."user_profiles" ADD COLUMN "target_weight_min_kg" numeric(5, 2);--> statement-breakpoint
ALTER TABLE "app"."user_profiles" ADD COLUMN "target_weight_max_kg" numeric(5, 2);--> statement-breakpoint
ALTER TABLE "app"."user_profiles" ADD COLUMN "weekly_rate_kg" numeric(4, 2);--> statement-breakpoint
ALTER TABLE "app"."user_profiles" ADD COLUMN "target_date" date;--> statement-breakpoint
ALTER TABLE "app"."user_profiles" ADD COLUMN "goal_started_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "app"."user_goals" ADD COLUMN "mode" varchar(10) DEFAULT 'auto' NOT NULL;--> statement-breakpoint
ALTER TABLE "app"."user_goals" ADD COLUMN "suggested_goals" jsonb;--> statement-breakpoint
ALTER TABLE "app"."user_goals" ADD COLUMN "suggestion_reason" varchar(100);--> statement-breakpoint
ALTER TABLE "app"."user_goals" ADD COLUMN "suggested_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "app"."user_goals" ADD COLUMN "suggestion_basis" jsonb;--> statement-breakpoint
ALTER TABLE "app"."user_goals" ADD COLUMN "applied_basis" jsonb;--> statement-breakpoint
ALTER TABLE "app"."user_goals" ADD COLUMN "manual_overrides" jsonb;--> statement-breakpoint
ALTER TABLE "app"."user_profiles" ADD CONSTRAINT "user_profiles_valid_targets" CHECK (("app"."user_profiles"."target_weight_kg" IS NULL OR ("app"."user_profiles"."target_weight_kg" >= 20 AND "app"."user_profiles"."target_weight_kg" <= 400))
        AND ("app"."user_profiles"."target_weight_min_kg" IS NULL OR ("app"."user_profiles"."target_weight_min_kg" >= 20 AND "app"."user_profiles"."target_weight_min_kg" <= 400))
        AND ("app"."user_profiles"."target_weight_max_kg" IS NULL OR ("app"."user_profiles"."target_weight_max_kg" >= 20 AND "app"."user_profiles"."target_weight_max_kg" <= 400))
        AND ("app"."user_profiles"."target_weight_min_kg" IS NULL OR "app"."user_profiles"."target_weight_max_kg" IS NULL OR "app"."user_profiles"."target_weight_min_kg" < "app"."user_profiles"."target_weight_max_kg")
        AND ("app"."user_profiles"."weekly_rate_kg" IS NULL OR ("app"."user_profiles"."weekly_rate_kg" > 0 AND "app"."user_profiles"."weekly_rate_kg" <= 2)));--> statement-breakpoint
ALTER TABLE "app"."user_goals" ADD CONSTRAINT "user_goals_mode_values" CHECK ("app"."user_goals"."mode" IN ('auto', 'manual'));