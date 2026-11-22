-- Backfill: ensure every non-user (system/usda/catalog) food has at least one
-- system portion. User-managed; review before applying.
--
-- Safe to run multiple times: inserts only when a food has no system serving.

INSERT INTO app.food_servings (food_id, name, grams, source, created_by)
SELECT f.id, '100 g', 100, 'system', NULL
FROM app.foods f
WHERE f.source <> 'user'
  AND NOT EXISTS (
    SELECT 1
    FROM app.food_servings fs
    WHERE fs.food_id = f.id
      AND fs.source = 'system'
  );
