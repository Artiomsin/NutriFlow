CREATE TABLE "app"."goal_history" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"goal_type" varchar(20) NOT NULL,
	"metric" varchar(40) NOT NULL,
	"old_value" integer,
	"new_value" integer,
	"source" varchar(20) NOT NULL,
	"reason" varchar(100),
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "app"."goal_recommendations" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"status" varchar(20) DEFAULT 'pending' NOT NULL,
	"previous_goals" jsonb NOT NULL,
	"recommended_goals" jsonb NOT NULL,
	"analysis_period_start" date NOT NULL,
	"analysis_period_end" date NOT NULL,
	"reasons" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"confidence" jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"accepted_at" timestamp with time zone,
	"dismissed_at" timestamp with time zone
);
--> statement-breakpoint
ALTER TABLE "app"."user_goals" ALTER COLUMN "source" SET DATA TYPE varchar(20);--> statement-breakpoint
ALTER TABLE "app"."user_goals" ALTER COLUMN "source" SET DEFAULT 'initial';--> statement-breakpoint
ALTER TABLE "app"."goal_history" ADD CONSTRAINT "goal_history_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "app"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "app"."goal_recommendations" ADD CONSTRAINT "goal_recommendations_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "app"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "idx_goal_history_user_created" ON "app"."goal_history" USING btree ("user_id","created_at");--> statement-breakpoint
CREATE INDEX "idx_goal_recommendations_user_created" ON "app"."goal_recommendations" USING btree ("user_id","created_at");--> statement-breakpoint
CREATE UNIQUE INDEX "uq_goal_recommendations_pending" ON "app"."goal_recommendations" USING btree ("user_id") WHERE "app"."goal_recommendations"."status" = 'pending';--> statement-breakpoint
UPDATE "app"."user_goals" SET "source" = 'initial' WHERE "source" = 'auto';--> statement-breakpoint
UPDATE "app"."user_goals" SET "source" = 'user' WHERE "source" = 'manual';