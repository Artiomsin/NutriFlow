ALTER TABLE "app"."food_servings" ADD COLUMN "source" varchar(10) DEFAULT 'system' NOT NULL;--> statement-breakpoint
ALTER TABLE "app"."food_servings" ADD COLUMN "created_by" uuid;--> statement-breakpoint
ALTER TABLE "app"."food_servings" ADD CONSTRAINT "food_servings_created_by_users_id_fk" FOREIGN KEY ("created_by") REFERENCES "app"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."food_servings" ADD CONSTRAINT "food_servings_source_values" CHECK ("app"."food_servings"."source" IN ('system','user'));--> statement-breakpoint
ALTER TABLE "app"."food_servings" ADD CONSTRAINT "food_servings_owner_required" CHECK ((("app"."food_servings"."source" = 'user') = ("app"."food_servings"."created_by" IS NOT NULL)));--> statement-breakpoint
CREATE INDEX "idx_food_servings_food_id" ON "app"."food_servings" USING btree ("food_id");
