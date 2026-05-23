CREATE TABLE "app"."user_goals" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"daily_calories_goal" integer,
	"daily_protein_goal" integer,
	"daily_fat_goal" integer,
	"daily_carbs_goal" integer,
	"daily_water_goal" integer,
	"source" varchar(10) DEFAULT 'auto',
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL,
	CONSTRAINT "user_goals_user_id_unique" UNIQUE("user_id")
);
--> statement-breakpoint
ALTER TABLE "app"."user_profiles" ADD COLUMN "gender" varchar(10);--> statement-breakpoint
ALTER TABLE "app"."user_goals" ADD CONSTRAINT "user_goals_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "app"."users"("id") ON DELETE cascade ON UPDATE no action;