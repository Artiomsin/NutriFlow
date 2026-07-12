-- Seed: 5 categories + 10 foods with images + servings
-- Schema: app
-- Run: psql -d nutriflow -f seed-catalog-with-images.sql
-- Safe: uses ON CONFLICT — won't error on existing data

-- ============ CATEGORIES ============
INSERT INTO app.food_categories (name, icon) VALUES
  ('Meat', '🥩'),
  ('Seafood', '🦐'),
  ('Vegetables', '🥦'),
  ('Fruits', '🍎'),
  ('Dairy', '🥛')
ON CONFLICT (name) DO NOTHING;

-- ============ FOODS + SERVINGS ============

-- 1. Chicken Breast (Meat)
WITH
  cat AS (SELECT id FROM app.food_categories WHERE name = 'Meat'),
  f AS (INSERT INTO app.foods
    (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, image_url, source)
    VALUES ('Chicken Breast', (SELECT id FROM cat), 165, 31, 4, 0,
      'https://images.unsplash.com/photo-1604503468506-a8da13d82791?w=400&h=400&fit=crop',
      'system')
    ON CONFLICT (name) DO UPDATE SET image_url = EXCLUDED.image_url
    RETURNING id)
INSERT INTO app.food_servings (food_id, name, grams)
  SELECT id, '100g', 100 FROM f UNION ALL
  SELECT id, '1 breast (200g)', 200 FROM f
ON CONFLICT DO NOTHING;

-- 2. Beef Steak (Meat)
WITH
  cat AS (SELECT id FROM app.food_categories WHERE name = 'Meat'),
  f AS (INSERT INTO app.foods
    (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, image_url, source)
    VALUES ('Beef Steak', (SELECT id FROM cat), 271, 26, 18, 0,
      'https://images.unsplash.com/photo-1544025162-d76694265947?w=400&h=400&fit=crop',
      'system')
    ON CONFLICT (name) DO UPDATE SET image_url = EXCLUDED.image_url
    RETURNING id)
INSERT INTO app.food_servings (food_id, name, grams)
  SELECT id, '100g', 100 FROM f UNION ALL
  SELECT id, '1 steak (250g)', 250 FROM f
ON CONFLICT DO NOTHING;

-- 3. Salmon (Seafood)
WITH
  cat AS (SELECT id FROM app.food_categories WHERE name = 'Seafood'),
  f AS (INSERT INTO app.foods
    (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, image_url, source)
    VALUES ('Salmon', (SELECT id FROM cat), 208, 20, 13, 0,
      'https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=400&h=400&fit=crop',
      'system')
    ON CONFLICT (name) DO UPDATE SET image_url = EXCLUDED.image_url
    RETURNING id)
INSERT INTO app.food_servings (food_id, name, grams)
  SELECT id, '100g', 100 FROM f UNION ALL
  SELECT id, '1 fillet (180g)', 180 FROM f
ON CONFLICT DO NOTHING;

-- 4. Shrimp (Seafood)
WITH
  cat AS (SELECT id FROM app.food_categories WHERE name = 'Seafood'),
  f AS (INSERT INTO app.foods
    (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, image_url, source)
    VALUES ('Shrimp', (SELECT id FROM cat), 85, 20, 1, 0,
      'https://images.unsplash.com/photo-1559737558-2f5a35f4523b?w=400&h=400&fit=crop',
      'system')
    ON CONFLICT (name) DO UPDATE SET image_url = EXCLUDED.image_url
    RETURNING id)
INSERT INTO app.food_servings (food_id, name, grams)
  SELECT id, '100g', 100 FROM f UNION ALL
  SELECT id, '10 pcs (80g)', 80 FROM f
ON CONFLICT DO NOTHING;

-- 5. Broccoli (Vegetables)
WITH
  cat AS (SELECT id FROM app.food_categories WHERE name = 'Vegetables'),
  f AS (INSERT INTO app.foods
    (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, image_url, source)
    VALUES ('Broccoli', (SELECT id FROM cat), 34, 3, 0, 7,
      'https://images.unsplash.com/photo-1459411621453-7b03977f4bfc?w=400&h=400&fit=crop',
      'system')
    ON CONFLICT (name) DO UPDATE SET image_url = EXCLUDED.image_url
    RETURNING id)
INSERT INTO app.food_servings (food_id, name, grams)
  SELECT id, '100g', 100 FROM f UNION ALL
  SELECT id, '1 cup (150g)', 150 FROM f
ON CONFLICT DO NOTHING;

-- 6. Sweet Potato (Vegetables)
WITH
  cat AS (SELECT id FROM app.food_categories WHERE name = 'Vegetables'),
  f AS (INSERT INTO app.foods
    (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, image_url, source)
    VALUES ('Sweet Potato', (SELECT id FROM cat), 86, 2, 0, 20,
      'https://images.unsplash.com/photo-1596097635121-14b0b4cd0b52?w=400&h=400&fit=crop',
      'system')
    ON CONFLICT (name) DO UPDATE SET image_url = EXCLUDED.image_url
    RETURNING id)
INSERT INTO app.food_servings (food_id, name, grams)
  SELECT id, '100g', 100 FROM f UNION ALL
  SELECT id, '1 medium (200g)', 200 FROM f
ON CONFLICT DO NOTHING;

-- 7. Banana (Fruits)
WITH
  cat AS (SELECT id FROM app.food_categories WHERE name = 'Fruits'),
  f AS (INSERT INTO app.foods
    (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, image_url, source)
    VALUES ('Banana', (SELECT id FROM cat), 89, 1, 0, 23,
      'https://images.unsplash.com/photo-1603833665858-e61d17a86224?w=400&h=400&fit=crop',
      'system')
    ON CONFLICT (name) DO UPDATE SET image_url = EXCLUDED.image_url
    RETURNING id)
INSERT INTO app.food_servings (food_id, name, grams)
  SELECT id, '100g', 100 FROM f UNION ALL
  SELECT id, '1 medium (120g)', 120 FROM f
ON CONFLICT DO NOTHING;

-- 8. Blueberries (Fruits)
WITH
  cat AS (SELECT id FROM app.food_categories WHERE name = 'Fruits'),
  f AS (INSERT INTO app.foods
    (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, image_url, source)
    VALUES ('Blueberries', (SELECT id FROM cat), 57, 1, 0, 14,
      'https://images.unsplash.com/photo-1498557850523-fd3d118b962e?w=400&h=400&fit=crop',
      'system')
    ON CONFLICT (name) DO UPDATE SET image_url = EXCLUDED.image_url
    RETURNING id)
INSERT INTO app.food_servings (food_id, name, grams)
  SELECT id, '100g', 100 FROM f UNION ALL
  SELECT id, '1 cup (150g)', 150 FROM f
ON CONFLICT DO NOTHING;

-- 9. Greek Yogurt (Dairy)
WITH
  cat AS (SELECT id FROM app.food_categories WHERE name = 'Dairy'),
  f AS (INSERT INTO app.foods
    (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, image_url, source)
    VALUES ('Greek Yogurt', (SELECT id FROM cat), 97, 9, 5, 4,
      'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=400&h=400&fit=crop',
      'system')
    ON CONFLICT (name) DO UPDATE SET image_url = EXCLUDED.image_url
    RETURNING id)
INSERT INTO app.food_servings (food_id, name, grams)
  SELECT id, '100g', 100 FROM f UNION ALL
  SELECT id, '1 cup (200g)', 200 FROM f
ON CONFLICT DO NOTHING;

-- 10. Cheddar Cheese (Dairy)
WITH
  cat AS (SELECT id FROM app.food_categories WHERE name = 'Dairy'),
  f AS (INSERT INTO app.foods
    (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, image_url, source)
    VALUES ('Cheddar Cheese', (SELECT id FROM cat), 403, 25, 33, 1,
      'https://images.unsplash.com/photo-1486297678162-eb2a19b0a32d?w=400&h=400&fit=crop',
      'system')
    ON CONFLICT (name) DO UPDATE SET image_url = EXCLUDED.image_url
    RETURNING id)
INSERT INTO app.food_servings (food_id, name, grams)
  SELECT id, '30g (slice)', 30 FROM f UNION ALL
  SELECT id, '100g', 100 FROM f
ON CONFLICT DO NOTHING;

-- ============ VERIFICATION ============
SELECT 'categories' AS entity, COUNT(*)::text AS count FROM app.food_categories
UNION ALL
SELECT 'foods', COUNT(*)::text FROM app.foods
UNION ALL
SELECT 'servings', COUNT(*)::text FROM app.food_servings
ORDER BY entity;
