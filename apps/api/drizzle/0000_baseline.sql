CREATE SCHEMA IF NOT EXISTS "app";--> statement-breakpoint
CREATE TABLE "app"."users" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"email" varchar(120) NOT NULL,
	"password_hash" varchar(255),
	"google_id" varchar(255),
	"apple_id" varchar(255),
	"first_name" varchar(50),
	"last_name" varchar(50),
	"avatar_url" varchar(500),
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL,
	CONSTRAINT "users_email_unique" UNIQUE("email"),
	CONSTRAINT "users_google_id_unique" UNIQUE("google_id"),
	CONSTRAINT "users_apple_id_unique" UNIQUE("apple_id")
);
--> statement-breakpoint
CREATE TABLE "app"."auth_sessions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"session_id" uuid NOT NULL,
	"refresh_token_hash" varchar(64) NOT NULL,
	"previous_refresh_token_hash" varchar(64),
	"previous_valid_until" timestamp with time zone,
	"expires_at" timestamp with time zone NOT NULL,
	"revoked_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "auth_sessions_valid_expiry" CHECK ("app"."auth_sessions"."expires_at" > "app"."auth_sessions"."created_at")
);
--> statement-breakpoint
CREATE TABLE "app"."user_profiles" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"weight" numeric(5, 2),
	"height" integer,
	"age" integer,
	"gender" varchar(10),
	"goal" varchar(20),
	"activity_level" varchar(20),
	"time_zone" varchar(64) DEFAULT 'UTC' NOT NULL,
	"preferred_units" jsonb DEFAULT '{"weight":"metric","volume":"metric","energy":"kcal"}'::jsonb NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL,
	CONSTRAINT "user_profiles_valid_measurements" CHECK (("app"."user_profiles"."weight" IS NULL OR ("app"."user_profiles"."weight" >= 20 AND "app"."user_profiles"."weight" <= 400))
        AND ("app"."user_profiles"."height" IS NULL OR ("app"."user_profiles"."height" >= 50 AND "app"."user_profiles"."height" <= 300))
        AND ("app"."user_profiles"."age" IS NULL OR ("app"."user_profiles"."age" >= 1 AND "app"."user_profiles"."age" <= 120))),
	CONSTRAINT "user_profiles_allowed_values" CHECK (("app"."user_profiles"."gender" IS NULL OR "app"."user_profiles"."gender" IN ('male', 'female'))
        AND ("app"."user_profiles"."goal" IS NULL OR "app"."user_profiles"."goal" IN ('lose', 'gain', 'maintain'))
        AND ("app"."user_profiles"."activity_level" IS NULL OR "app"."user_profiles"."activity_level" IN ('low', 'medium', 'high')))
);
--> statement-breakpoint
CREATE TABLE "app"."water_entries" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"amount_ml" integer NOT NULL,
	"entry_date" date NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "water_entries_amount_range" CHECK ("app"."water_entries"."amount_ml" >= 1 AND "app"."water_entries"."amount_ml" <= 3000)
);
--> statement-breakpoint
CREATE TABLE "app"."daily_summary" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"date" date NOT NULL,
	"total_calories" integer DEFAULT 0,
	"total_protein" integer DEFAULT 0,
	"total_fat" integer DEFAULT 0,
	"total_carbs" integer DEFAULT 0,
	"total_water_ml" integer DEFAULT 0,
	"created_at" timestamp DEFAULT now() NOT NULL,
	CONSTRAINT "daily_summary_non_negative_totals" CHECK ("app"."daily_summary"."total_calories" >= 0 AND "app"."daily_summary"."total_protein" >= 0
        AND "app"."daily_summary"."total_fat" >= 0 AND "app"."daily_summary"."total_carbs" >= 0
        AND "app"."daily_summary"."total_water_ml" >= 0)
);
--> statement-breakpoint
CREATE TABLE "app"."food_entries" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"food_id" uuid,
	"name" varchar(120) NOT NULL,
	"grams" integer,
	"unit" varchar(10) DEFAULT 'g' NOT NULL,
	"calories" integer NOT NULL,
	"protein" integer DEFAULT 0,
	"fat" integer DEFAULT 0,
	"carbs" integer DEFAULT 0,
	"image_url" varchar(500),
	"entry_date" date NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "food_entries_value_ranges" CHECK (("app"."food_entries"."grams" IS NULL OR ("app"."food_entries"."grams" >= 0 AND "app"."food_entries"."grams" <= 10000))
        AND "app"."food_entries"."calories" >= 0 AND "app"."food_entries"."calories" <= 5000
        AND "app"."food_entries"."protein" >= 0 AND "app"."food_entries"."protein" <= 1000
        AND "app"."food_entries"."fat" >= 0 AND "app"."food_entries"."fat" <= 1000
        AND "app"."food_entries"."carbs" >= 0 AND "app"."food_entries"."carbs" <= 1000)
);
--> statement-breakpoint
CREATE TABLE "app"."user_goals" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"daily_calories_goal" integer,
	"daily_protein_goal" integer,
	"daily_fat_goal" integer,
	"daily_carbs_goal" integer,
	"daily_water_goal" integer,
	"daily_steps_goal" integer,
	"daily_active_calories_goal" integer,
	"weekly_workouts_goal" integer,
	"weekly_workout_minutes_goal" integer,
	"nightly_sleep_min_minutes" integer,
	"nightly_sleep_max_minutes" integer,
	"source" varchar(20) DEFAULT 'initial',
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL,
	CONSTRAINT "user_goals_user_id_unique" UNIQUE("user_id"),
	CONSTRAINT "user_goals_positive_values" CHECK (("app"."user_goals"."daily_calories_goal" IS NULL OR "app"."user_goals"."daily_calories_goal" > 0)
      AND ("app"."user_goals"."daily_protein_goal" IS NULL OR "app"."user_goals"."daily_protein_goal" > 0)
      AND ("app"."user_goals"."daily_fat_goal" IS NULL OR "app"."user_goals"."daily_fat_goal" > 0)
      AND ("app"."user_goals"."daily_carbs_goal" IS NULL OR "app"."user_goals"."daily_carbs_goal" > 0)
      AND ("app"."user_goals"."daily_water_goal" IS NULL OR "app"."user_goals"."daily_water_goal" > 0)
      AND ("app"."user_goals"."daily_steps_goal" IS NULL OR "app"."user_goals"."daily_steps_goal" > 0)
      AND ("app"."user_goals"."daily_active_calories_goal" IS NULL OR "app"."user_goals"."daily_active_calories_goal" > 0)
      AND ("app"."user_goals"."weekly_workouts_goal" IS NULL OR "app"."user_goals"."weekly_workouts_goal" > 0)
      AND ("app"."user_goals"."weekly_workout_minutes_goal" IS NULL OR "app"."user_goals"."weekly_workout_minutes_goal" > 0)
      AND ("app"."user_goals"."nightly_sleep_min_minutes" IS NULL OR "app"."user_goals"."nightly_sleep_min_minutes" > 0)
      AND ("app"."user_goals"."nightly_sleep_max_minutes" IS NULL OR "app"."user_goals"."nightly_sleep_max_minutes" > 0)),
	CONSTRAINT "user_goals_sleep_range" CHECK ("app"."user_goals"."nightly_sleep_min_minutes" IS NULL OR "app"."user_goals"."nightly_sleep_max_minutes" IS NULL
      OR "app"."user_goals"."nightly_sleep_min_minutes" <= "app"."user_goals"."nightly_sleep_max_minutes"),
	CONSTRAINT "user_goals_source_values" CHECK ("app"."user_goals"."source" IN ('initial', 'user', 'personalized'))
);
--> statement-breakpoint
CREATE TABLE "app"."food_categories" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" varchar(100) NOT NULL,
	"icon" varchar(50),
	"created_at" timestamp DEFAULT now() NOT NULL,
	CONSTRAINT "food_categories_name_unique" UNIQUE("name"),
	CONSTRAINT "food_categories_non_blank_name" CHECK (char_length(trim("app"."food_categories"."name")) > 0)
);
--> statement-breakpoint
CREATE TABLE "app"."foods" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" varchar(255) NOT NULL,
	"category_id" uuid,
	"calories_per_100g" integer NOT NULL,
	"protein_per_100g" integer DEFAULT 0,
	"fat_per_100g" integer DEFAULT 0,
	"carbs_per_100g" integer DEFAULT 0,
	"barcode" varchar(50),
	"image_url" varchar(500),
	"brand" varchar(200),
	"source" varchar(20) DEFAULT 'user' NOT NULL,
	"forked_from_id" uuid,
	"created_by" uuid,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL,
	CONSTRAINT "foods_nutrient_ranges" CHECK ("app"."foods"."calories_per_100g" >= 0 AND "app"."foods"."calories_per_100g" <= 1000
        AND "app"."foods"."protein_per_100g" >= 0 AND "app"."foods"."protein_per_100g" <= 100
        AND "app"."foods"."fat_per_100g" >= 0 AND "app"."foods"."fat_per_100g" <= 100
        AND "app"."foods"."carbs_per_100g" >= 0 AND "app"."foods"."carbs_per_100g" <= 100),
	CONSTRAINT "foods_source_values" CHECK ("app"."foods"."source" IN ('user', 'system', 'usda'))
);
--> statement-breakpoint
CREATE TABLE "app"."food_servings" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"food_id" uuid NOT NULL,
	"name" varchar(100) NOT NULL,
	"grams" integer NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL,
	CONSTRAINT "food_servings_valid_serving" CHECK (char_length(trim("app"."food_servings"."name")) > 0 AND "app"."food_servings"."grams" >= 0 AND "app"."food_servings"."grams" <= 10000)
);
--> statement-breakpoint
CREATE TABLE "app"."user_food_stats" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"food_id" uuid NOT NULL,
	"frequency" integer DEFAULT 0,
	"last_used_at" timestamp DEFAULT now(),
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "app"."daily_activity" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"date" date NOT NULL,
	"steps" integer DEFAULT 0 NOT NULL,
	"active_calories" integer DEFAULT 0 NOT NULL,
	"basal_calories" integer DEFAULT 0 NOT NULL,
	"distance_meters" numeric(10, 2) DEFAULT '0',
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL,
	CONSTRAINT "daily_activity_metric_ranges" CHECK ("app"."daily_activity"."steps" >= 0 AND "app"."daily_activity"."steps" <= 200000
        AND "app"."daily_activity"."active_calories" >= 0 AND "app"."daily_activity"."active_calories" <= 20000
        AND "app"."daily_activity"."basal_calories" >= 0 AND "app"."daily_activity"."basal_calories" <= 20000
        AND "app"."daily_activity"."distance_meters" >= 0 AND "app"."daily_activity"."distance_meters" <= 1000000)
);
--> statement-breakpoint
CREATE TABLE "app"."user_workouts" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"healthkit_workout_id" varchar(64) NOT NULL,
	"type" varchar(50) NOT NULL,
	"start_date" timestamp with time zone NOT NULL,
	"end_date" timestamp with time zone NOT NULL,
	"local_date" date NOT NULL,
	"duration_seconds" numeric(10, 3) NOT NULL,
	"calories_burned" numeric(10, 2),
	"distance_meters" numeric(10, 2),
	"heart_rate_avg" numeric(5, 1),
	"heart_rate_max" numeric(5, 1),
	"heart_rate_min" numeric(5, 1),
	"avg_speed_mps" numeric(10, 2),
	"max_speed_mps" numeric(10, 2),
	"avg_cadence" numeric(10, 2),
	"max_cadence" numeric(10, 2),
	"avg_power_watts" numeric(10, 2),
	"max_power_watts" numeric(10, 2),
	"elevation_gain_meters" numeric(10, 2),
	"steps" integer,
	"indoor" boolean,
	"details" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL,
	CONSTRAINT "user_workouts_valid_timing" CHECK ("app"."user_workouts"."end_date" > "app"."user_workouts"."start_date" AND "app"."user_workouts"."duration_seconds" >= 0
        AND "app"."user_workouts"."duration_seconds" <= 86400),
	CONSTRAINT "user_workouts_non_negative_metrics" CHECK (("app"."user_workouts"."calories_burned" IS NULL OR "app"."user_workouts"."calories_burned" >= 0)
        AND ("app"."user_workouts"."distance_meters" IS NULL OR "app"."user_workouts"."distance_meters" >= 0)
        AND ("app"."user_workouts"."heart_rate_avg" IS NULL OR ("app"."user_workouts"."heart_rate_avg" >= 0 AND "app"."user_workouts"."heart_rate_avg" <= 300))
        AND ("app"."user_workouts"."heart_rate_max" IS NULL OR ("app"."user_workouts"."heart_rate_max" >= 0 AND "app"."user_workouts"."heart_rate_max" <= 300))
        AND ("app"."user_workouts"."heart_rate_min" IS NULL OR ("app"."user_workouts"."heart_rate_min" >= 0 AND "app"."user_workouts"."heart_rate_min" <= 300))
        AND ("app"."user_workouts"."steps" IS NULL OR "app"."user_workouts"."steps" >= 0))
);
--> statement-breakpoint
CREATE TABLE "app"."user_sleep" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"start_date" timestamp with time zone NOT NULL,
	"end_date" timestamp with time zone NOT NULL,
	"local_date" date NOT NULL,
	"time_in_bed_seconds" numeric(12, 1),
	"asleep_seconds" numeric(12, 1),
	"awake_seconds" numeric(12, 1),
	"core_seconds" numeric(12, 1),
	"deep_seconds" numeric(12, 1),
	"rem_seconds" numeric(12, 1),
	"unspecified_seconds" numeric(12, 1),
	"awakenings" integer,
	"onset_latency_seconds" numeric(12, 1),
	"efficiency" numeric(5, 2),
	"segment_count" integer,
	"heart_rate_avg" numeric(5, 1),
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL,
	CONSTRAINT "user_sleep_valid_timing" CHECK ("app"."user_sleep"."end_date" > "app"."user_sleep"."start_date"),
	CONSTRAINT "user_sleep_metric_ranges" CHECK (("app"."user_sleep"."time_in_bed_seconds" IS NULL OR ("app"."user_sleep"."time_in_bed_seconds" >= 0 AND "app"."user_sleep"."time_in_bed_seconds" <= 86400))
        AND ("app"."user_sleep"."asleep_seconds" IS NULL OR ("app"."user_sleep"."asleep_seconds" >= 0 AND "app"."user_sleep"."asleep_seconds" <= 86400))
        AND ("app"."user_sleep"."awake_seconds" IS NULL OR ("app"."user_sleep"."awake_seconds" >= 0 AND "app"."user_sleep"."awake_seconds" <= 86400))
        AND ("app"."user_sleep"."core_seconds" IS NULL OR ("app"."user_sleep"."core_seconds" >= 0 AND "app"."user_sleep"."core_seconds" <= 86400))
        AND ("app"."user_sleep"."deep_seconds" IS NULL OR ("app"."user_sleep"."deep_seconds" >= 0 AND "app"."user_sleep"."deep_seconds" <= 86400))
        AND ("app"."user_sleep"."rem_seconds" IS NULL OR ("app"."user_sleep"."rem_seconds" >= 0 AND "app"."user_sleep"."rem_seconds" <= 86400))
        AND ("app"."user_sleep"."unspecified_seconds" IS NULL OR ("app"."user_sleep"."unspecified_seconds" >= 0 AND "app"."user_sleep"."unspecified_seconds" <= 86400))
        AND ("app"."user_sleep"."awakenings" IS NULL OR "app"."user_sleep"."awakenings" >= 0)
        AND ("app"."user_sleep"."onset_latency_seconds" IS NULL OR "app"."user_sleep"."onset_latency_seconds" >= 0)
        AND ("app"."user_sleep"."efficiency" IS NULL OR ("app"."user_sleep"."efficiency" >= 0 AND "app"."user_sleep"."efficiency" <= 100))
        AND ("app"."user_sleep"."segment_count" IS NULL OR "app"."user_sleep"."segment_count" >= 0)
        AND ("app"."user_sleep"."heart_rate_avg" IS NULL OR ("app"."user_sleep"."heart_rate_avg" >= 0 AND "app"."user_sleep"."heart_rate_avg" <= 300)))
);
--> statement-breakpoint
CREATE TABLE "app"."weight_logs" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"weight_kg" numeric(5, 2) NOT NULL,
	"entry_date" date NOT NULL,
	"source" varchar(10) DEFAULT 'manual' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "weight_logs_weight_range" CHECK ("app"."weight_logs"."weight_kg" >= 20 AND "app"."weight_logs"."weight_kg" <= 400),
	CONSTRAINT "weight_logs_source_values" CHECK ("app"."weight_logs"."source" IN ('initial', 'manual'))
);
--> statement-breakpoint
CREATE TABLE "app"."goal_history" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"goal_type" varchar(20) NOT NULL,
	"metric" varchar(40) NOT NULL,
	"old_value" integer,
	"new_value" integer,
	"source" varchar(20) NOT NULL,
	"reason" varchar(100),
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "app"."goal_recommendations" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"status" varchar(20) DEFAULT 'pending' NOT NULL,
	"previous_goals" jsonb NOT NULL,
	"recommended_goals" jsonb NOT NULL,
	"analysis_period_start" date NOT NULL,
	"analysis_period_end" date NOT NULL,
	"reasons" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"confidence" jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"accepted_at" timestamp with time zone,
	"dismissed_at" timestamp with time zone
);
--> statement-breakpoint
ALTER TABLE "app"."auth_sessions" ADD CONSTRAINT "auth_sessions_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "app"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."user_profiles" ADD CONSTRAINT "user_profiles_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "app"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."water_entries" ADD CONSTRAINT "water_entries_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "app"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."daily_summary" ADD CONSTRAINT "daily_summary_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "app"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."food_entries" ADD CONSTRAINT "food_entries_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "app"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."food_entries" ADD CONSTRAINT "food_entries_food_id_foods_id_fk" FOREIGN KEY ("food_id") REFERENCES "app"."foods"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."user_goals" ADD CONSTRAINT "user_goals_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "app"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."foods" ADD CONSTRAINT "foods_category_id_food_categories_id_fk" FOREIGN KEY ("category_id") REFERENCES "app"."food_categories"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."foods" ADD CONSTRAINT "foods_created_by_users_id_fk" FOREIGN KEY ("created_by") REFERENCES "app"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."foods" ADD CONSTRAINT "foods_forked_from_id_foods_id_fk" FOREIGN KEY ("forked_from_id") REFERENCES "app"."foods"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."food_servings" ADD CONSTRAINT "food_servings_food_id_foods_id_fk" FOREIGN KEY ("food_id") REFERENCES "app"."foods"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."user_food_stats" ADD CONSTRAINT "user_food_stats_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "app"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."user_food_stats" ADD CONSTRAINT "user_food_stats_food_id_foods_id_fk" FOREIGN KEY ("food_id") REFERENCES "app"."foods"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."daily_activity" ADD CONSTRAINT "daily_activity_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "app"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."user_workouts" ADD CONSTRAINT "user_workouts_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "app"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."user_sleep" ADD CONSTRAINT "user_sleep_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "app"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."weight_logs" ADD CONSTRAINT "weight_logs_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "app"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."goal_history" ADD CONSTRAINT "goal_history_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "app"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."goal_recommendations" ADD CONSTRAINT "goal_recommendations_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "app"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "uq_auth_sessions_session_id" ON "app"."auth_sessions" USING btree ("session_id");--> statement-breakpoint
CREATE INDEX "idx_auth_sessions_user_id" ON "app"."auth_sessions" USING btree ("user_id");--> statement-breakpoint
CREATE UNIQUE INDEX "idx_user_profiles_user_id_unique" ON "app"."user_profiles" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "idx_water_entries_user_date" ON "app"."water_entries" USING btree ("user_id","entry_date");--> statement-breakpoint
CREATE UNIQUE INDEX "daily_summary_user_date_key" ON "app"."daily_summary" USING btree ("user_id","date");--> statement-breakpoint
CREATE INDEX "idx_food_entries_user_date" ON "app"."food_entries" USING btree ("user_id","entry_date");--> statement-breakpoint
CREATE INDEX "idx_foods_name_fts" ON "app"."foods" USING gin (to_tsvector('simple', "name"));--> statement-breakpoint
CREATE UNIQUE INDEX "uq_catalog_foods_barcode" ON "app"."foods" USING btree ("barcode") WHERE "app"."foods"."barcode" IS NOT NULL AND "app"."foods"."source" IN ('system', 'usda');--> statement-breakpoint
CREATE INDEX "idx_foods_category_id" ON "app"."foods" USING btree ("category_id");--> statement-breakpoint
CREATE UNIQUE INDEX "user_food_stats_user_id_food_id_index" ON "app"."user_food_stats" USING btree ("user_id","food_id");--> statement-breakpoint
CREATE UNIQUE INDEX "daily_activity_user_date_key" ON "app"."daily_activity" USING btree ("user_id","date");--> statement-breakpoint
CREATE UNIQUE INDEX "user_workouts_user_workout_key" ON "app"."user_workouts" USING btree ("user_id","healthkit_workout_id");--> statement-breakpoint
CREATE INDEX "user_workouts_user_start_idx" ON "app"."user_workouts" USING btree ("user_id","start_date");--> statement-breakpoint
CREATE UNIQUE INDEX "user_sleep_user_start_key" ON "app"."user_sleep" USING btree ("user_id","start_date");--> statement-breakpoint
CREATE UNIQUE INDEX "uq_weight_logs_user_date" ON "app"."weight_logs" USING btree ("user_id","entry_date");--> statement-breakpoint
CREATE INDEX "idx_weight_logs_user_date" ON "app"."weight_logs" USING btree ("user_id","entry_date");--> statement-breakpoint
CREATE INDEX "idx_goal_history_user_created" ON "app"."goal_history" USING btree ("user_id","created_at");--> statement-breakpoint
CREATE INDEX "idx_goal_recommendations_user_created" ON "app"."goal_recommendations" USING btree ("user_id","created_at");--> statement-breakpoint
CREATE UNIQUE INDEX "uq_goal_recommendations_pending" ON "app"."goal_recommendations" USING btree ("user_id") WHERE "app"."goal_recommendations"."status" = 'pending';