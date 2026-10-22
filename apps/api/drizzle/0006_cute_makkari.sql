ALTER TABLE "app"."food_categories" DROP CONSTRAINT "food_categories_name_unique";--> statement-breakpoint
ALTER TABLE "app"."food_categories" ADD COLUMN "created_by" uuid;--> statement-breakpoint
ALTER TABLE "app"."food_categories" ADD CONSTRAINT "food_categories_created_by_users_id_fk" FOREIGN KEY ("created_by") REFERENCES "app"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "uq_category_system_name" ON "app"."food_categories" USING btree ("name") WHERE "app"."food_categories"."created_by" IS NULL;--> statement-breakpoint
CREATE UNIQUE INDEX "uq_category_user_name" ON "app"."food_categories" USING btree ("created_by","name") WHERE "app"."food_categories"."created_by" IS NOT NULL;--> statement-breakpoint
CREATE INDEX "idx_food_categories_created_by" ON "app"."food_categories" USING btree ("created_by");
