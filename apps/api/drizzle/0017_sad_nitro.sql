CREATE TABLE "app"."user_workouts" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"healthkit_workout_id" varchar(64) NOT NULL,
	"type" varchar(50) NOT NULL,
	"start_date" timestamp with time zone NOT NULL,
	"end_date" timestamp with time zone NOT NULL,
	"duration_seconds" numeric(10, 3) NOT NULL,
	"calories_burned" numeric(10, 2),
	"distance_meters" numeric(10, 2),
	"source" varchar(10) DEFAULT 'healthkit',
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "app"."daily_activity" ADD COLUMN "basal_calories" integer DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE "app"."user_workouts" ADD CONSTRAINT "user_workouts_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "app"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "user_workouts_user_workout_key" ON "app"."user_workouts" USING btree ("user_id","healthkit_workout_id");