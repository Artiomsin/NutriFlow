ALTER TABLE "app"."user_goals" DROP CONSTRAINT "user_goals_user_id_unique";--> statement-breakpoint
CREATE INDEX "idx_user_goals_user_id" ON "app"."user_goals" USING btree ("user_id");