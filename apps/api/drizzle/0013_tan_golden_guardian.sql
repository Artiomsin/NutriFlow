DROP INDEX "app"."idx_food_entries_created_at";--> statement-breakpoint
CREATE INDEX "idx_water_entries_user_date" ON "app"."water_entries" USING btree ("user_id","entry_date");--> statement-breakpoint
CREATE INDEX "idx_food_entries_user_date" ON "app"."food_entries" USING btree ("user_id","entry_date");