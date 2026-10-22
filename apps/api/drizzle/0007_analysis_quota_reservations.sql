CREATE TABLE "app"."analysis_quota_reservations" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
  "user_id" uuid NOT NULL,
  "status" varchar(10) NOT NULL,
  "reserved_at" timestamp with time zone DEFAULT now() NOT NULL,
  "expires_at" timestamp with time zone NOT NULL,
  CONSTRAINT "analysis_quota_reservations_valid_status" CHECK ("status" IN ('pending', 'consumed'))
);
--> statement-breakpoint
ALTER TABLE "app"."analysis_quota_reservations" ADD CONSTRAINT "analysis_quota_reservations_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "app"."users"("id") ON DELETE CASCADE ON UPDATE NO ACTION;
--> statement-breakpoint
CREATE INDEX "idx_analysis_quota_reservations_user_expiry" ON "app"."analysis_quota_reservations" USING btree ("user_id","expires_at");
--> statement-breakpoint
INSERT INTO "app"."analysis_quota_reservations" ("id", "user_id", "status", "reserved_at", "expires_at")
SELECT gen_random_uuid(), quotas.user_id, 'consumed', now(), now() + interval '24 hours'
FROM "app"."analysis_quotas" AS quotas
CROSS JOIN LATERAL generate_series(1, quotas.count)
WHERE quotas.date = CURRENT_DATE AND quotas.count > 0;
--> statement-breakpoint
DROP TABLE "app"."analysis_quotas";
