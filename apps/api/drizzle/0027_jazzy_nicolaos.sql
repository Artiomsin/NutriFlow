CREATE TABLE "app"."auth_sessions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"session_id" uuid NOT NULL,
	"refresh_token_hash" varchar(64) NOT NULL,
	"previous_refresh_token_hash" varchar(64),
	"previous_valid_until" timestamp with time zone,
	"expires_at" timestamp with time zone NOT NULL,
	"revoked_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "app"."auth_sessions" ADD CONSTRAINT "auth_sessions_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "app"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "uq_auth_sessions_session_id" ON "app"."auth_sessions" USING btree ("session_id");--> statement-breakpoint
CREATE INDEX "idx_auth_sessions_user_id" ON "app"."auth_sessions" USING btree ("user_id");