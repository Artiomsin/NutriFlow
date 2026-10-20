ALTER TABLE "app"."goal_history" ADD COLUMN "updated_at" timestamp with time zone DEFAULT now() NOT NULL;--> statement-breakpoint
CREATE INDEX "idx_goal_history_user_updated" ON "app"."goal_history" USING btree ("user_id", "updated_at");
