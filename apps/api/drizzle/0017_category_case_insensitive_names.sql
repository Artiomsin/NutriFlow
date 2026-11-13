-- Enforcing case-insensitive uniqueness fails with an opaque Postgres error
-- when duplicates already exist. Surface the offending names instead so the
-- deploy stops with an actionable message rather than a broken index build.
DO $$
DECLARE
  duplicated text;
BEGIN
  SELECT string_agg(msg, E'\n')
  INTO duplicated
  FROM (
    SELECT format('system category "%s"', lower(name)) AS msg
    FROM "app"."food_categories"
    WHERE "created_by" IS NULL
    GROUP BY lower(name)
    HAVING count(*) > 1
    UNION ALL
    SELECT format('user %s category "%s"', "created_by", lower(name))
    FROM "app"."food_categories"
    WHERE "created_by" IS NOT NULL
    GROUP BY "created_by", lower(name)
    HAVING count(*) > 1
  ) duplicates;

  IF duplicated IS NOT NULL THEN
    RAISE EXCEPTION 'Case-insensitive category names collide. Rename or remove these rows, then re-run the migration:%', E'\n' || duplicated;
  END IF;
END $$;--> statement-breakpoint
DROP INDEX "app"."uq_category_system_name";--> statement-breakpoint
DROP INDEX "app"."uq_category_user_name";--> statement-breakpoint
CREATE UNIQUE INDEX "uq_category_system_name" ON "app"."food_categories" USING btree (lower("name")) WHERE "app"."food_categories"."created_by" IS NULL;--> statement-breakpoint
CREATE UNIQUE INDEX "uq_category_user_name" ON "app"."food_categories" USING btree ("created_by",lower("name")) WHERE "app"."food_categories"."created_by" IS NOT NULL;
