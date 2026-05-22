-- =============================================================
-- NutriFlow — тестовые данные для Beekeeper Studio
--
-- 1. Узнать свой ID: SELECT id, email FROM app.users;
-- 2. Заменить ID внизу в SET my.user_id
-- 3. Выделить нужную секцию и запустить
-- =============================================================

SET my.user_id = '11111111-1111-1111-1111-111111111111';  -- ← замените на свой ID

-- =============================================================
-- 1а. ЕДА НА СЕГОДНЯ (по часам)
-- =============================================================
INSERT INTO app.food_entries (id, user_id, name, calories, protein, fat, carbs, created_at)
SELECT
  gen_random_uuid(), current_setting('my.user_id')::uuid, v.*
FROM (VALUES
  ('Овсянка с ягодами',  350, 12, 8,  58,  (CURRENT_DATE + '01:00:00'::time)::timestamp),
  ('Кофе с молоком',      120, 4,  6,  10,  (CURRENT_DATE + '02:00:00'::time)::timestamp),
  ('Куриная грудка',      165, 31, 4,  0,   (CURRENT_DATE + '10:00:00'::time)::timestamp),
  ('Рис отварной',        200, 4,  1,  45,  (CURRENT_DATE + '12:00:00'::time)::timestamp),
  ('Яблоко',              95,  0,  0,  25,  (CURRENT_DATE + '12:00:00'::time)::timestamp),
  ('Лосось на гриле',     367, 34, 22, 0,   (CURRENT_DATE + '14:00:00'::time)::timestamp),
  ('Брокколи',            55,  4,  1,  11,  (CURRENT_DATE + '14:00:00'::time)::timestamp),
  ('Греческий йогурт',    150, 15, 4,  10,  (CURRENT_DATE + '15:00:00'::time)::timestamp)
) AS v(name, calories, protein, fat, carbs, created_at);

-- =============================================================
-- 1б. ВОДА НА СЕГОДНЯ (по часам)
-- =============================================================
INSERT INTO app.water_entries (id, user_id, amount_ml, created_at)
SELECT gen_random_uuid(), current_setting('my.user_id')::uuid, v.*
FROM (VALUES
  (300, (CURRENT_DATE + '08:00:00'::time)::timestamp),
  (500, (CURRENT_DATE + '10:30:00'::time)::timestamp),
  (400, (CURRENT_DATE + '12:00:00'::time)::timestamp),
  (350, (CURRENT_DATE + '15:00:00'::time)::timestamp),
  (250, (CURRENT_DATE + '11:00:00'::time)::timestamp),
  (200, (CURRENT_DATE + '9:00:00'::time)::timestamp)
) AS v(amount_ml, created_at);

-- =============================================================
-- 2. НЕДЕЛЯ — daily_summary (7 дней)
-- =============================================================
INSERT INTO app.daily_summary (id, user_id, date, total_calories, total_protein, total_fat, total_carbs, total_water_ml)
SELECT gen_random_uuid(), current_setting('my.user_id')::uuid,
  (CURRENT_DATE - make_interval(days => d))::timestamp,
  (1500 + random() * 1000)::int, (60 + random() * 60)::int,
  (30 + random() * 40)::int, (100 + random() * 100)::int,
  (1500 + random() * 1000)::int
FROM generate_series(0, 6) AS d;

-- =============================================================
-- 3. МЕСЯЦ — daily_summary (30 дней)
-- =============================================================
INSERT INTO app.daily_summary (id, user_id, date, total_calories, total_protein, total_fat, total_carbs, total_water_ml)
SELECT gen_random_uuid(), current_setting('my.user_id')::uuid,
  (CURRENT_DATE - make_interval(days => d))::timestamp,
  (1500 + random() * 1000)::int, (60 + random() * 60)::int,
  (30 + random() * 40)::int, (100 + random() * 100)::int,
  (1500 + random() * 1000)::int
FROM generate_series(0, 29) AS d;

-- =============================================================
-- 4. ГОД — daily_summary (365 дней)
-- =============================================================
INSERT INTO app.daily_summary (id, user_id, date, total_calories, total_protein, total_fat, total_carbs, total_water_ml)
SELECT gen_random_uuid(), current_setting('my.user_id')::uuid,
  (CURRENT_DATE - make_interval(days => d))::timestamp,
  (1500 + random() * 1000)::int, (60 + random() * 60)::int,
  (30 + random() * 40)::int, (100 + random() * 100)::int,
  (1500 + random() * 1000)::int
FROM generate_series(0, 364) AS d;

-- =============================================================
-- ОЧИСТКА (запустить перед повторным заполнением)
-- =============================================================
-- DELETE FROM app.food_entries  WHERE user_id = current_setting('my.user_id')::uuid;
-- DELETE FROM app.water_entries WHERE user_id = current_setting('my.user_id')::uuid;
-- DELETE FROM app.daily_summary WHERE user_id = current_setting('my.user_id')::uuid;

-- =============================================================
-- ПРОВЕРКА
-- =============================================================
-- SELECT 'food' AS tbl, count(*) FROM app.food_entries  WHERE user_id = current_setting('my.user_id')::uuid
-- UNION ALL SELECT 'water', count(*) FROM app.water_entries WHERE user_id = current_setting('my.user_id')::uuid
-- UNION ALL SELECT 'daily_summary', count(*) FROM app.daily_summary WHERE user_id = current_setting('my.user_id')::uuid;
