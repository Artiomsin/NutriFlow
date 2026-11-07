ALTER TABLE "app"."user_goals" ADD COLUMN "started_at" timestamp with time zone DEFAULT now() NOT NULL;--> statement-breakpoint
ALTER TABLE "app"."user_goals" ADD COLUMN "ended_at" timestamp with time zone;
