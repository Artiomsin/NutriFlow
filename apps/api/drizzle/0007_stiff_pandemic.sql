ALTER TABLE "app"."foods" DROP CONSTRAINT "foods_created_by_users_id_fk";
--> statement-breakpoint
DROP INDEX "app"."idx_foods_name";--> statement-breakpoint
ALTER TABLE "app"."foods" ADD CONSTRAINT "foods_created_by_users_id_fk" FOREIGN KEY ("created_by") REFERENCES "app"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "idx_user_profiles_user_id_unique" ON "app"."user_profiles" USING btree ("user_id");--> statement-breakpoint
CREATE UNIQUE INDEX "idx_foods_name_unique" ON "app"."foods" USING btree ("name");