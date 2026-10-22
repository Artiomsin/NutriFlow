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
ALTER TABLE "app"."user_uploads" ADD CONSTRAINT "user_uploads_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "app"."users"("id") ON DELETE cascade ON UPDATE no action;
--> statement-breakpoint
CREATE UNIQUE INDEX "uq_user_uploads_object_key" ON "app"."user_uploads" USING btree ("object_key");
--> statement-breakpoint
CREATE INDEX "idx_user_uploads_user_id" ON "app"."user_uploads" USING btree ("user_id");
--> statement-breakpoint
CREATE UNIQUE INDEX "uq_storage_cleanup_tasks_object_key" ON "app"."storage_cleanup_tasks" USING btree ("object_key");
--> statement-breakpoint
CREATE INDEX "idx_storage_cleanup_tasks_pending" ON "app"."storage_cleanup_tasks" USING btree ("next_attempt_at") WHERE "app"."storage_cleanup_tasks"."completed_at" IS NULL;
--> statement-breakpoint
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM "app"."foods"
    WHERE ("source" = 'user' AND "created_by" IS NULL)
       OR ("source" <> 'user' AND "created_by" IS NOT NULL)
  ) THEN
    RAISE EXCEPTION 'Cannot add foods owner rule: existing rows have inconsistent source and created_by';
  END IF;
END $$;
--> statement-breakpoint
ALTER TABLE "app"."foods" DROP CONSTRAINT "foods_created_by_users_id_fk";
--> statement-breakpoint
ALTER TABLE "app"."foods" ADD CONSTRAINT "foods_created_by_users_id_fk" FOREIGN KEY ("created_by") REFERENCES "app"."users"("id") ON DELETE cascade ON UPDATE no action;
--> statement-breakpoint
ALTER TABLE "app"."foods" ADD CONSTRAINT "foods_owner_required" CHECK (("source" = 'user') = ("created_by" IS NOT NULL));
--> statement-breakpoint
ALTER TABLE "app"."foods" DROP CONSTRAINT "foods_category_id_food_categories_id_fk";
--> statement-breakpoint
ALTER TABLE "app"."foods" ADD CONSTRAINT "foods_category_id_food_categories_id_fk" FOREIGN KEY ("category_id") REFERENCES "app"."food_categories"("id") ON DELETE set null ON UPDATE no action;
--> statement-breakpoint
ALTER TABLE "app"."food_entries" DROP CONSTRAINT "food_entries_food_id_foods_id_fk";
--> statement-breakpoint
ALTER TABLE "app"."food_entries" ADD CONSTRAINT "food_entries_food_id_foods_id_fk" FOREIGN KEY ("food_id") REFERENCES "app"."foods"("id") ON DELETE set null ON UPDATE no action;
