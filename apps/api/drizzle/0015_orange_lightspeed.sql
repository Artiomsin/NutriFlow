ALTER TABLE "app"."users" ADD COLUMN "apple_id" varchar(255);--> statement-breakpoint
ALTER TABLE "app"."users" ADD CONSTRAINT "users_apple_id_unique" UNIQUE("apple_id");