CREATE TABLE "app"."analysis_quota_reservations" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"status" varchar(10) NOT NULL,
	"reserved_at" timestamp with time zone DEFAULT now() NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	CONSTRAINT "analysis_quota_reservations_valid_status" CHECK ("app"."analysis_quota_reservations"."status" IN ('pending', 'consumed'))
);
--> statement-breakpoint
CREATE TABLE "app"."user_uploads" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"object_key" varchar(500) NOT NULL,
	"content_type" varchar(100) NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "app"."storage_cleanup_tasks" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"object_key" varchar(500) NOT NULL,
	"attempts" integer DEFAULT 0 NOT NULL,
	"next_attempt_at" timestamp with time zone DEFAULT now() NOT NULL,
	"last_error" varchar(1000),
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"completed_at" timestamp with time zone
);
--> statement-breakpoint
ALTER TABLE "app"."analysis_quotas" DISABLE ROW LEVEL SECURITY;--> statement-breakpoint
DROP TABLE "app"."analysis_quotas" CASCADE;--> statement-breakpoint
ALTER TABLE "app"."food_entries" DROP CONSTRAINT "food_entries_food_id_foods_id_fk";
--> statement-breakpoint
ALTER TABLE "app"."foods" DROP CONSTRAINT "foods_category_id_food_categories_id_fk";
--> statement-breakpoint
ALTER TABLE "app"."foods" DROP CONSTRAINT "foods_created_by_users_id_fk";
--> statement-breakpoint
ALTER TABLE "app"."daily_summary" ALTER COLUMN "total_calories" SET DATA TYPE numeric(10, 1);--> statement-breakpoint
ALTER TABLE "app"."daily_summary" ALTER COLUMN "total_protein" SET DATA TYPE numeric(10, 1);--> statement-breakpoint
ALTER TABLE "app"."daily_summary" ALTER COLUMN "total_fat" SET DATA TYPE numeric(10, 1);--> statement-breakpoint
ALTER TABLE "app"."daily_summary" ALTER COLUMN "total_carbs" SET DATA TYPE numeric(10, 1);--> statement-breakpoint
ALTER TABLE "app"."food_entries" ALTER COLUMN "grams" SET DATA TYPE numeric(10, 3);--> statement-breakpoint
ALTER TABLE "app"."food_entries" ALTER COLUMN "calories" SET DATA TYPE numeric(10, 1);--> statement-breakpoint
ALTER TABLE "app"."food_entries" ALTER COLUMN "protein" SET DATA TYPE numeric(10, 1);--> statement-breakpoint
ALTER TABLE "app"."food_entries" ALTER COLUMN "fat" SET DATA TYPE numeric(10, 1);--> statement-breakpoint
ALTER TABLE "app"."food_entries" ALTER COLUMN "carbs" SET DATA TYPE numeric(10, 1);--> statement-breakpoint
ALTER TABLE "app"."user_goals" ALTER COLUMN "daily_calories_goal" SET DATA TYPE numeric(10, 1);--> statement-breakpoint
ALTER TABLE "app"."user_goals" ALTER COLUMN "daily_protein_goal" SET DATA TYPE numeric(10, 1);--> statement-breakpoint
ALTER TABLE "app"."user_goals" ALTER COLUMN "daily_fat_goal" SET DATA TYPE numeric(10, 1);--> statement-breakpoint
ALTER TABLE "app"."user_goals" ALTER COLUMN "daily_carbs_goal" SET DATA TYPE numeric(10, 1);--> statement-breakpoint
ALTER TABLE "app"."foods" ALTER COLUMN "calories_per_100g" SET DATA TYPE numeric(10, 1);--> statement-breakpoint
ALTER TABLE "app"."foods" ALTER COLUMN "protein_per_100g" SET DATA TYPE numeric(10, 1);--> statement-breakpoint
ALTER TABLE "app"."foods" ALTER COLUMN "fat_per_100g" SET DATA TYPE numeric(10, 1);--> statement-breakpoint
ALTER TABLE "app"."foods" ALTER COLUMN "carbs_per_100g" SET DATA TYPE numeric(10, 1);--> statement-breakpoint
ALTER TABLE "app"."food_servings" ALTER COLUMN "grams" SET DATA TYPE numeric(10, 3);--> statement-breakpoint
ALTER TABLE "app"."daily_activity" ALTER COLUMN "active_calories" SET DATA TYPE numeric(10, 1);--> statement-breakpoint
ALTER TABLE "app"."daily_activity" ALTER COLUMN "basal_calories" SET DATA TYPE numeric(10, 1);--> statement-breakpoint
ALTER TABLE "app"."goal_history" ALTER COLUMN "old_value" SET DATA TYPE numeric(10, 1);--> statement-breakpoint
ALTER TABLE "app"."goal_history" ALTER COLUMN "new_value" SET DATA TYPE numeric(10, 1);--> statement-breakpoint
ALTER TABLE "app"."user_goals" ADD COLUMN "started_at" timestamp with time zone DEFAULT now() NOT NULL;--> statement-breakpoint
ALTER TABLE "app"."user_goals" ADD COLUMN "ended_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "app"."analysis_quota_reservations" ADD CONSTRAINT "analysis_quota_reservations_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "app"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."user_uploads" ADD CONSTRAINT "user_uploads_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "app"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "idx_analysis_quota_reservations_user_expiry" ON "app"."analysis_quota_reservations" USING btree ("user_id","expires_at");--> statement-breakpoint
CREATE UNIQUE INDEX "uq_user_uploads_object_key" ON "app"."user_uploads" USING btree ("object_key");--> statement-breakpoint
CREATE INDEX "idx_user_uploads_user_id" ON "app"."user_uploads" USING btree ("user_id");--> statement-breakpoint
CREATE UNIQUE INDEX "uq_storage_cleanup_tasks_object_key" ON "app"."storage_cleanup_tasks" USING btree ("object_key");--> statement-breakpoint
CREATE INDEX "idx_storage_cleanup_tasks_pending" ON "app"."storage_cleanup_tasks" USING btree ("next_attempt_at") WHERE "app"."storage_cleanup_tasks"."completed_at" IS NULL;--> statement-breakpoint
ALTER TABLE "app"."food_entries" ADD CONSTRAINT "food_entries_food_id_foods_id_fk" FOREIGN KEY ("food_id") REFERENCES "app"."foods"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."foods" ADD CONSTRAINT "foods_category_id_food_categories_id_fk" FOREIGN KEY ("category_id") REFERENCES "app"."food_categories"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."foods" ADD CONSTRAINT "foods_created_by_users_id_fk" FOREIGN KEY ("created_by") REFERENCES "app"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."foods" ADD CONSTRAINT "foods_owner_required" CHECK (("app"."foods"."source" = 'user') = ("app"."foods"."created_by" IS NOT NULL));