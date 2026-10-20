CREATE INDEX "idx_rate_limits_expires_at" ON "app"."rate_limits" USING btree ("expires_at");--> statement-breakpoint
CREATE INDEX "idx_analysis_quotas_date" ON "app"."analysis_quotas" USING btree ("date");
