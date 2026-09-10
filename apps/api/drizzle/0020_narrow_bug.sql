CREATE TABLE "app"."user_sleep" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"start_date" timestamp with time zone NOT NULL,
	"end_date" timestamp with time zone NOT NULL,
	"time_in_bed_seconds" numeric(12, 1),
	"asleep_seconds" numeric(12, 1),
	"awake_seconds" numeric(12, 1),
	"core_seconds" numeric(12, 1),
	"deep_seconds" numeric(12, 1),
	"rem_seconds" numeric(12, 1),
	"unspecified_seconds" numeric(12, 1),
	"awakenings" integer,
	"onset_latency_seconds" numeric(12, 1),
	"efficiency" numeric(5, 2),
	"segment_count" integer,
	"heart_rate_avg" numeric(5, 1),
	"sources" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"night_metrics" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"source" varchar(10) DEFAULT 'healthkit',
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "app"."user_workouts" ADD COLUMN "steps" integer;--> statement-breakpoint
ALTER TABLE "app"."user_workouts" ADD COLUMN "indoor" boolean;--> statement-breakpoint
ALTER TABLE "app"."user_sleep" ADD CONSTRAINT "user_sleep_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "app"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "user_sleep_user_start_key" ON "app"."user_sleep" USING btree ("user_id","start_date");