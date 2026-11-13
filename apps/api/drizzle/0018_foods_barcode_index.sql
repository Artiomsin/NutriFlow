-- Barcode lookups scan both the shared catalog and personal products, but the
-- only barcode index before this migration covered catalog rows
-- (source IN ('system','usda')), so personal products forced a sequential scan.
--
-- IF NOT EXISTS keeps this migration safe for the large-table deploy flow:
-- pre-create the index manually with CREATE INDEX CONCURRENTLY (drizzle runs
-- migrations inside a transaction, where CONCURRENTLY is not allowed), then let
-- this statement become a no-op.
CREATE INDEX IF NOT EXISTS "idx_foods_barcode" ON "app"."foods" USING btree ("barcode") WHERE "app"."foods"."barcode" IS NOT NULL;
