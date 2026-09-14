CREATE TABLE "app"."weight_logs" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"weight_kg" numeric(5, 2) NOT NULL,
	"entry_date" date NOT NULL,
	"source" varchar(10) DEFAULT 'manual' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "app"."weight_logs" ADD CONSTRAINT "weight_logs_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "app"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "uq_weight_logs_user_date" ON "app"."weight_logs" USING btree ("user_id","entry_date");--> statement-breakpoint
CREATE INDEX "idx_weight_logs_user_date" ON "app"."weight_logs" USING btree ("user_id","entry_date");