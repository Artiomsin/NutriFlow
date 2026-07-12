-- Seed: Food categories + catalog foods + servings
-- Run in Beekeeper Studio or psql
-- Schema: app (public)

-- ============ CATEGORIES ============

-- Уже есть: Meat, Fruits, Dairy
-- Добавляем 6 новых:

INSERT INTO app.food_categories (name, icon) VALUES
  ('Vegetables', '🥦'),
  ('Grains', '🌾'),
  ('Legumes', '🫘'),
  ('Nuts & Seeds', '🥜'),
  ('Seafood', '🦐'),
  ('Eggs', '🥚');

-- ============ FOODS + SERVINGS ============

-- ----- Vegetables -----
WITH cat AS (SELECT id FROM app.food_categories WHERE name = 'Vegetables'),
     f1 AS (INSERT INTO app.foods (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, source)
       VALUES ('Broccoli', (SELECT id FROM cat), 34, 3, 0, 7, 'system') RETURNING id),
     f2 AS (INSERT INTO app.foods (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, source)
       VALUES ('Spinach', (SELECT id FROM cat), 23, 3, 0, 4, 'system') RETURNING id),
     f3 AS (INSERT INTO app.foods (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, source)
       VALUES ('Sweet Potato', (SELECT id FROM cat), 86, 2, 0, 20, 'system') RETURNING id)
INSERT INTO app.food_servings (food_id, name, grams)
  SELECT id, '100g', 100 FROM f1 UNION ALL
  SELECT id, '1 cup (150g)', 150 FROM f1 UNION ALL
  SELECT id, '100g', 100 FROM f2 UNION ALL
  SELECT id, '1 cup (30g)', 30 FROM f2 UNION ALL
  SELECT id, '100g', 100 FROM f3 UNION ALL
  SELECT id, '1 medium (200g)', 200 FROM f3;

-- ----- Grains -----
WITH cat AS (SELECT id FROM app.food_categories WHERE name = 'Grains'),
     f1 AS (INSERT INTO app.foods (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, source)
       VALUES ('Brown Rice', (SELECT id FROM cat), 111, 3, 1, 23, 'system') RETURNING id),
     f2 AS (INSERT INTO app.foods (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, source)
       VALUES ('Oatmeal', (SELECT id FROM cat), 71, 3, 1, 12, 'system') RETURNING id),
     f3 AS (INSERT INTO app.foods (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, source)
       VALUES ('Quinoa', (SELECT id FROM cat), 120, 4, 2, 21, 'system') RETURNING id)
INSERT INTO app.food_servings (food_id, name, grams)
  SELECT id, '100g', 100 FROM f1 UNION ALL
  SELECT id, '1 cup (200g)', 200 FROM f1 UNION ALL
  SELECT id, '100g', 100 FROM f2 UNION ALL
  SELECT id, '1 bowl (250g)', 250 FROM f2 UNION ALL
  SELECT id, '100g', 100 FROM f3 UNION ALL
  SELECT id, '1 cup (180g)', 180 FROM f3;

-- ----- Legumes -----
WITH cat AS (SELECT id FROM app.food_categories WHERE name = 'Legumes'),
     f1 AS (INSERT INTO app.foods (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, source)
       VALUES ('Chickpeas', (SELECT id FROM cat), 139, 8, 3, 23, 'system') RETURNING id),
     f2 AS (INSERT INTO app.foods (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, source)
       VALUES ('Lentils', (SELECT id FROM cat), 116, 9, 0, 20, 'system') RETURNING id)
INSERT INTO app.food_servings (food_id, name, grams)
  SELECT id, '100g', 100 FROM f1 UNION ALL
  SELECT id, '1 cup (200g)', 200 FROM f1 UNION ALL
  SELECT id, '100g', 100 FROM f2 UNION ALL
  SELECT id, '1 cup (200g)', 200 FROM f2;

-- ----- Nuts & Seeds -----
WITH cat AS (SELECT id FROM app.food_categories WHERE name = 'Nuts & Seeds'),
     f1 AS (INSERT INTO app.foods (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, source)
       VALUES ('Almonds', (SELECT id FROM cat), 579, 21, 50, 22, 'system') RETURNING id),
     f2 AS (INSERT INTO app.foods (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, source)
       VALUES ('Walnuts', (SELECT id FROM cat), 654, 15, 65, 14, 'system') RETURNING id),
     f3 AS (INSERT INTO app.foods (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, source)
       VALUES ('Chia Seeds', (SELECT id FROM cat), 486, 17, 31, 42, 'system') RETURNING id)
INSERT INTO app.food_servings (food_id, name, grams)
  SELECT id, '30g (handful)', 30 FROM f1 UNION ALL
  SELECT id, '100g', 100 FROM f1 UNION ALL
  SELECT id, '30g (handful)', 30 FROM f2 UNION ALL
  SELECT id, '100g', 100 FROM f2 UNION ALL
  SELECT id, '15g (1 tbsp)', 15 FROM f3 UNION ALL
  SELECT id, '100g', 100 FROM f3;

-- ----- Seafood -----
WITH cat AS (SELECT id FROM app.food_categories WHERE name = 'Seafood'),
     f1 AS (INSERT INTO app.foods (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, source)
       VALUES ('Salmon', (SELECT id FROM cat), 208, 20, 13, 0, 'system') RETURNING id),
     f2 AS (INSERT INTO app.foods (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, source)
       VALUES ('Shrimp', (SELECT id FROM cat), 85, 20, 1, 0, 'system') RETURNING id),
     f3 AS (INSERT INTO app.foods (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, source)
       VALUES ('Tuna (canned)', (SELECT id FROM cat), 132, 29, 1, 0, 'system') RETURNING id)
INSERT INTO app.food_servings (food_id, name, grams)
  SELECT id, '100g', 100 FROM f1 UNION ALL
  SELECT id, '1 fillet (180g)', 180 FROM f1 UNION ALL
  SELECT id, '100g', 100 FROM f2 UNION ALL
  SELECT id, '10 pcs (80g)', 80 FROM f2 UNION ALL
  SELECT id, '100g', 100 FROM f3 UNION ALL
  SELECT id, '1 can (150g)', 150 FROM f3;

-- ----- Eggs -----
WITH cat AS (SELECT id FROM app.food_categories WHERE name = 'Eggs'),
     f1 AS (INSERT INTO app.foods (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, source)
       VALUES ('Chicken Egg', (SELECT id FROM cat), 155, 13, 11, 1, 'system') RETURNING id),
     f2 AS (INSERT INTO app.foods (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, source)
       VALUES ('Egg White', (SELECT id FROM cat), 52, 11, 0, 1, 'system') RETURNING id)
INSERT INTO app.food_servings (food_id, name, grams)
  SELECT id, '1 egg (50g)', 50 FROM f1 UNION ALL
  SELECT id, '2 eggs (100g)', 100 FROM f1 UNION ALL
  SELECT id, '100g', 100 FROM f2 UNION ALL
  SELECT id, '3 whites (100g)', 100 FROM f2;

-- ----- Dishes (also in Vegetables) -----
WITH cat AS (SELECT id FROM app.food_categories WHERE name = 'Vegetables'),
     f1 AS (INSERT INTO app.foods (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, source)
       VALUES ('Chicken Teriyaki with Rice', (SELECT id FROM cat), 150, 12, 4, 18, 'system') RETURNING id),
     f2 AS (INSERT INTO app.foods (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, source)
       VALUES ('Caesar Salad', (SELECT id FROM cat), 130, 15, 8, 4, 'system') RETURNING id)
INSERT INTO app.food_servings (food_id, name, grams)
  SELECT id, '1 bowl (300g)', 300 FROM f1 UNION ALL
  SELECT id, '1 portion (250g)', 250 FROM f1 UNION ALL
  SELECT id, '1 bowl (250g)', 250 FROM f2 UNION ALL
  SELECT id, '1 portion (200g)', 200 FROM f2;

-- ----- More existing categories food -----
WITH cat AS (SELECT id FROM app.food_categories WHERE name = 'Meat'),
     f1 AS (INSERT INTO app.foods (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, source)
       VALUES ('Chicken Wing', (SELECT id FROM cat), 203, 18, 14, 0, 'system') RETURNING id),
     f2 AS (INSERT INTO app.foods (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, source)
       VALUES ('Beef Steak', (SELECT id FROM cat), 271, 26, 18, 0, 'system') RETURNING id)
INSERT INTO app.food_servings (food_id, name, grams)
  SELECT id, '1 wing (50g)', 50 FROM f1 UNION ALL
  SELECT id, '4 wings (200g)', 200 FROM f1 UNION ALL
  SELECT id, '100g', 100 FROM f2 UNION ALL
  SELECT id, '1 steak (250g)', 250 FROM f2;

WITH cat AS (SELECT id FROM app.food_categories WHERE name = 'Dairy'),
     f1 AS (INSERT INTO app.foods (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, source)
       VALUES ('Greek Yogurt', (SELECT id FROM cat), 97, 9, 5, 4, 'system') RETURNING id),
     f2 AS (INSERT INTO app.foods (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, source)
       VALUES ('Cheddar Cheese', (SELECT id FROM cat), 403, 25, 33, 1, 'system') RETURNING id)
INSERT INTO app.food_servings (food_id, name, grams)
  SELECT id, '1 cup (200g)', 200 FROM f1 UNION ALL
  SELECT id, '100g', 100 FROM f1 UNION ALL
  SELECT id, '30g (slice)', 30 FROM f2 UNION ALL
  SELECT id, '100g', 100 FROM f2;

WITH cat AS (SELECT id FROM app.food_categories WHERE name = 'Fruits'),
     f1 AS (INSERT INTO app.foods (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, source)
       VALUES ('Avocado', (SELECT id FROM cat), 160, 2, 15, 9, 'system') RETURNING id),
     f2 AS (INSERT INTO app.foods (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, source)
       VALUES ('Blueberries', (SELECT id FROM cat), 57, 1, 0, 14, 'system') RETURNING id)
INSERT INTO app.food_servings (food_id, name, grams)
  SELECT id, '1/2 avocado (75g)', 75 FROM f1 UNION ALL
  SELECT id, '1 whole (150g)', 150 FROM f1 UNION ALL
  SELECT id, '1 cup (150g)', 150 FROM f2 UNION ALL
  SELECT id, '100g', 100 FROM f2;

-- ----- Extra foods to reach 30 -----
WITH cat AS (SELECT id FROM app.food_categories WHERE name = 'Vegetables'),
     f1 AS (INSERT INTO app.foods (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, source)
       VALUES ('Cucumber', (SELECT id FROM cat), 15, 1, 0, 4, 'system') RETURNING id),
     f2 AS (INSERT INTO app.foods (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, source)
       VALUES ('Carrot', (SELECT id FROM cat), 41, 1, 0, 10, 'system') RETURNING id)
INSERT INTO app.food_servings (food_id, name, grams)
  SELECT id, '100g', 100 FROM f1 UNION ALL
  SELECT id, '1 whole (200g)', 200 FROM f1 UNION ALL
  SELECT id, '100g', 100 FROM f2 UNION ALL
  SELECT id, '1 medium (80g)', 80 FROM f2;

WITH cat AS (SELECT id FROM app.food_categories WHERE name = 'Fruits'),
     f1 AS (INSERT INTO app.foods (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, source)
       VALUES ('Banana', (SELECT id FROM cat), 89, 1, 0, 23, 'system') RETURNING id),
     f2 AS (INSERT INTO app.foods (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, source)
       VALUES ('Apple', (SELECT id FROM cat), 52, 0, 0, 14, 'system') RETURNING id)
INSERT INTO app.food_servings (food_id, name, grams)
  SELECT id, '100g', 100 FROM f1 UNION ALL
  SELECT id, '1 medium (120g)', 120 FROM f1 UNION ALL
  SELECT id, '100g', 100 FROM f2 UNION ALL
  SELECT id, '1 medium (180g)', 180 FROM f2;

WITH cat AS (SELECT id FROM app.food_categories WHERE name = 'Dairy'),
     f1 AS (INSERT INTO app.foods (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, source)
       VALUES ('Milk 2%', (SELECT id FROM cat), 50, 3, 2, 5, 'system') RETURNING id)
INSERT INTO app.food_servings (food_id, name, grams)
  SELECT id, '100ml', 100 FROM f1 UNION ALL
  SELECT id, '1 cup (250ml)', 250 FROM f1;

WITH cat AS (SELECT id FROM app.food_categories WHERE name = 'Seafood'),
     f1 AS (INSERT INTO app.foods (name, category_id, calories_per_100g, protein_per_100g, fat_per_100g, carbs_per_100g, source)
       VALUES ('Cod', (SELECT id FROM cat), 82, 18, 1, 0, 'system') RETURNING id)
INSERT INTO app.food_servings (food_id, name, grams)
  SELECT id, '100g', 100 FROM f1 UNION ALL
  SELECT id, '1 fillet (200g)', 200 FROM f1;

-- ============ VERIFICATION ============

SELECT 'categories' AS entity, COUNT(*)::text AS count FROM app.food_categories
UNION ALL
SELECT 'foods', COUNT(*)::text FROM app.foods
UNION ALL
SELECT 'servings', COUNT(*)::text FROM app.food_servings
ORDER BY entity;

SELECT fc.name AS category, COUNT(f.id) AS foods
FROM app.food_categories fc
LEFT JOIN app.foods f ON f.category_id = fc.id
GROUP BY fc.name
ORDER BY fc.name;
