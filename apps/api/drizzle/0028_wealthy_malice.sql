ALTER TABLE "app"."foods" DROP CONSTRAINT "foods_barcode_unique";--> statement-breakpoint
DROP INDEX "app"."idx_foods_name_unique";--> statement-breakpoint
CREATE UNIQUE INDEX "uq_catalog_foods_barcode" ON "app"."foods" USING btree ("barcode") WHERE "app"."foods"."barcode" IS NOT NULL AND "app"."foods"."source" IN ('system', 'usda');