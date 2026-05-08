import { Module } from "@nestjs/common";
import { ConfigModule } from "@nestjs/config";
import { LoggerModule } from "nestjs-pino";

import { DbModule } from "./db/db.module";
import { UsersModule } from "./users/users.module";
import { AuthModule } from "./auth/auth.module";
import { ProfilesModule } from "./profiles/profiles.module";
import { FoodModule } from './food/food.module';
import { WaterTrackingModule } from './water-tracking/water-tracking.module';
import { DailySummaryModule } from './daily-summary/daily-summary.module';

@Module({
  imports: [
   
    ConfigModule.forRoot({
      isGlobal: true,
    }),

    
    LoggerModule.forRoot({
      pinoHttp: {
        transport:
          process.env.NODE_ENV !== "production"
            ? {
                target: "pino-pretty",
                options: {
                  colorize: true,
                  translateTime: "SYS:standard",
                },
              }
            : undefined,
      },
    }),

    DbModule,
    UsersModule,
    AuthModule,
    ProfilesModule,
    FoodModule,
    WaterTrackingModule,
    DailySummaryModule,
  ],
})
export class AppModule {}