CREATE INDEX IF NOT EXISTS "idx_food_entries_created_at" ON "app"."food_entries" USING btree ("created_at");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "idx_foods_name_fts" ON "app"."foods" USING gin (to_tsvector('simple', "name"));--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "idx_foods_name" ON "app"."foods" USING btree ("name");--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "idx_foods_category_id" ON "app"."foods" USING btree ("category_id");