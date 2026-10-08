ALTER TABLE "app"."auth_sessions" ADD CONSTRAINT "auth_sessions_valid_expiry" CHECK ("app"."auth_sessions"."expires_at" > "app"."auth_sessions"."created_at");--> statement-breakpoint
ALTER TABLE "app"."user_profiles" ADD CONSTRAINT "user_profiles_valid_measurements" CHECK (("app"."user_profiles"."weight" IS NULL OR ("app"."user_profiles"."weight" >= 20 AND "app"."user_profiles"."weight" <= 400))
        AND ("app"."user_profiles"."height" IS NULL OR ("app"."user_profiles"."height" >= 50 AND "app"."user_profiles"."height" <= 300))
        AND ("app"."user_profiles"."age" IS NULL OR ("app"."user_profiles"."age" >= 1 AND "app"."user_profiles"."age" <= 120)));--> statement-breakpoint
ALTER TABLE "app"."user_profiles" ADD CONSTRAINT "user_profiles_allowed_values" CHECK (("app"."user_profiles"."gender" IS NULL OR "app"."user_profiles"."gender" IN ('male', 'female'))
        AND ("app"."user_profiles"."goal" IS NULL OR "app"."user_profiles"."goal" IN ('lose', 'gain', 'maintain'))
        AND ("app"."user_profiles"."activity_level" IS NULL OR "app"."user_profiles"."activity_level" IN ('low', 'medium', 'high')));--> statement-breakpoint
ALTER TABLE "app"."water_entries" ADD CONSTRAINT "water_entries_amount_range" CHECK ("app"."water_entries"."amount_ml" >= 1 AND "app"."water_entries"."amount_ml" <= 3000);--> statement-breakpoint
ALTER TABLE "app"."daily_summary" ADD CONSTRAINT "daily_summary_non_negative_totals" CHECK ("app"."daily_summary"."total_calories" >= 0 AND "app"."daily_summary"."total_protein" >= 0
        AND "app"."daily_summary"."total_fat" >= 0 AND "app"."daily_summary"."total_carbs" >= 0
        AND "app"."daily_summary"."total_water_ml" >= 0);--> statement-breakpoint
ALTER TABLE "app"."food_entries" ADD CONSTRAINT "food_entries_value_ranges" CHECK (("app"."food_entries"."grams" IS NULL OR ("app"."food_entries"."grams" >= 0 AND "app"."food_entries"."grams" <= 10000))
        AND "app"."food_entries"."calories" >= 0 AND "app"."food_entries"."calories" <= 5000
        AND "app"."food_entries"."protein" >= 0 AND "app"."food_entries"."protein" <= 1000
        AND "app"."food_entries"."fat" >= 0 AND "app"."food_entries"."fat" <= 1000
        AND "app"."food_entries"."carbs" >= 0 AND "app"."food_entries"."carbs" <= 1000);--> statement-breakpoint
ALTER TABLE "app"."user_goals" ADD CONSTRAINT "user_goals_positive_values" CHECK (("app"."user_goals"."daily_calories_goal" IS NULL OR "app"."user_goals"."daily_calories_goal" > 0)
      AND ("app"."user_goals"."daily_protein_goal" IS NULL OR "app"."user_goals"."daily_protein_goal" > 0)
      AND ("app"."user_goals"."daily_fat_goal" IS NULL OR "app"."user_goals"."daily_fat_goal" > 0)
      AND ("app"."user_goals"."daily_carbs_goal" IS NULL OR "app"."user_goals"."daily_carbs_goal" > 0)
      AND ("app"."user_goals"."daily_water_goal" IS NULL OR "app"."user_goals"."daily_water_goal" > 0)
      AND ("app"."user_goals"."daily_steps_goal" IS NULL OR "app"."user_goals"."daily_steps_goal" > 0)
      AND ("app"."user_goals"."daily_active_calories_goal" IS NULL OR "app"."user_goals"."daily_active_calories_goal" > 0)
      AND ("app"."user_goals"."weekly_workouts_goal" IS NULL OR "app"."user_goals"."weekly_workouts_goal" > 0)
      AND ("app"."user_goals"."weekly_workout_minutes_goal" IS NULL OR "app"."user_goals"."weekly_workout_minutes_goal" > 0)
      AND ("app"."user_goals"."nightly_sleep_min_minutes" IS NULL OR "app"."user_goals"."nightly_sleep_min_minutes" > 0)
      AND ("app"."user_goals"."nightly_sleep_max_minutes" IS NULL OR "app"."user_goals"."nightly_sleep_max_minutes" > 0));--> statement-breakpoint
ALTER TABLE "app"."user_goals" ADD CONSTRAINT "user_goals_sleep_range" CHECK ("app"."user_goals"."nightly_sleep_min_minutes" IS NULL OR "app"."user_goals"."nightly_sleep_max_minutes" IS NULL
      OR "app"."user_goals"."nightly_sleep_min_minutes" <= "app"."user_goals"."nightly_sleep_max_minutes");--> statement-breakpoint
ALTER TABLE "app"."user_goals" ADD CONSTRAINT "user_goals_source_values" CHECK ("app"."user_goals"."source" IN ('initial', 'user', 'personalized'));--> statement-breakpoint
ALTER TABLE "app"."food_categories" ADD CONSTRAINT "food_categories_non_blank_name" CHECK (char_length(trim("app"."food_categories"."name")) > 0);--> statement-breakpoint
ALTER TABLE "app"."foods" ADD CONSTRAINT "foods_nutrient_ranges" CHECK ("app"."foods"."calories_per_100g" >= 0 AND "app"."foods"."calories_per_100g" <= 1000
        AND "app"."foods"."protein_per_100g" >= 0 AND "app"."foods"."protein_per_100g" <= 100
        AND "app"."foods"."fat_per_100g" >= 0 AND "app"."foods"."fat_per_100g" <= 100
        AND "app"."foods"."carbs_per_100g" >= 0 AND "app"."foods"."carbs_per_100g" <= 100);--> statement-breakpoint
ALTER TABLE "app"."foods" ADD CONSTRAINT "foods_source_values" CHECK ("app"."foods"."source" IN ('user', 'system', 'usda'));--> statement-breakpoint
ALTER TABLE "app"."food_servings" ADD CONSTRAINT "food_servings_valid_serving" CHECK (char_length(trim("app"."food_servings"."name")) > 0 AND "app"."food_servings"."grams" >= 0 AND "app"."food_servings"."grams" <= 10000);--> statement-breakpoint
ALTER TABLE "app"."daily_activity" ADD CONSTRAINT "daily_activity_metric_ranges" CHECK ("app"."daily_activity"."steps" >= 0 AND "app"."daily_activity"."steps" <= 200000
        AND "app"."daily_activity"."active_calories" >= 0 AND "app"."daily_activity"."active_calories" <= 20000
        AND "app"."daily_activity"."basal_calories" >= 0 AND "app"."daily_activity"."basal_calories" <= 20000
        AND "app"."daily_activity"."distance_meters" >= 0 AND "app"."daily_activity"."distance_meters" <= 1000000);--> statement-breakpoint
ALTER TABLE "app"."user_workouts" ADD CONSTRAINT "user_workouts_valid_timing" CHECK ("app"."user_workouts"."end_date" > "app"."user_workouts"."start_date" AND "app"."user_workouts"."duration_seconds" >= 0
        AND "app"."user_workouts"."duration_seconds" <= 86400);--> statement-breakpoint
ALTER TABLE "app"."user_workouts" ADD CONSTRAINT "user_workouts_non_negative_metrics" CHECK (("app"."user_workouts"."calories_burned" IS NULL OR "app"."user_workouts"."calories_burned" >= 0)
        AND ("app"."user_workouts"."distance_meters" IS NULL OR "app"."user_workouts"."distance_meters" >= 0)
        AND ("app"."user_workouts"."heart_rate_avg" IS NULL OR ("app"."user_workouts"."heart_rate_avg" >= 0 AND "app"."user_workouts"."heart_rate_avg" <= 300))
        AND ("app"."user_workouts"."heart_rate_max" IS NULL OR ("app"."user_workouts"."heart_rate_max" >= 0 AND "app"."user_workouts"."heart_rate_max" <= 300))
        AND ("app"."user_workouts"."heart_rate_min" IS NULL OR ("app"."user_workouts"."heart_rate_min" >= 0 AND "app"."user_workouts"."heart_rate_min" <= 300))
        AND ("app"."user_workouts"."steps" IS NULL OR "app"."user_workouts"."steps" >= 0));--> statement-breakpoint
ALTER TABLE "app"."user_sleep" ADD CONSTRAINT "user_sleep_valid_timing" CHECK ("app"."user_sleep"."end_date" > "app"."user_sleep"."start_date");--> statement-breakpoint
ALTER TABLE "app"."user_sleep" ADD CONSTRAINT "user_sleep_metric_ranges" CHECK (("app"."user_sleep"."time_in_bed_seconds" IS NULL OR ("app"."user_sleep"."time_in_bed_seconds" >= 0 AND "app"."user_sleep"."time_in_bed_seconds" <= 86400))
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
        AND ("app"."user_sleep"."heart_rate_avg" IS NULL OR ("app"."user_sleep"."heart_rate_avg" >= 0 AND "app"."user_sleep"."heart_rate_avg" <= 300)));--> statement-breakpoint
ALTER TABLE "app"."weight_logs" ADD CONSTRAINT "weight_logs_weight_range" CHECK ("app"."weight_logs"."weight_kg" >= 20 AND "app"."weight_logs"."weight_kg" <= 400);--> statement-breakpoint
ALTER TABLE "app"."weight_logs" ADD CONSTRAINT "weight_logs_source_values" CHECK ("app"."weight_logs"."source" IN ('initial', 'manual'));