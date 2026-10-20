CREATE TABLE "app"."rate_limits" (
	"key" varchar(64) PRIMARY KEY NOT NULL,
	"total_hits" integer DEFAULT 0 NOT NULL,
	"expires_at" timestamp with time zone NOT NULL
);
--> statement-breakpoint
CREATE TABLE "app"."analysis_quotas" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"date" date NOT NULL,
	"count" integer DEFAULT 0 NOT NULL
);
--> statement-breakpoint
ALTER TABLE "app"."analysis_quotas" ADD CONSTRAINT "analysis_quotas_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "app"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "uq_analysis_quotas_user_date" ON "app"."analysis_quotas" USING btree ("user_id","date");