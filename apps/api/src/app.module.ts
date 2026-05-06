import { Module } from "@nestjs/common";
import { UsersModule } from './users/users.module';
import { AuthModule } from './auth/auth.module';
import { ProfilesModule } from './profiles/profiles.module';
import { ConfigModule } from '@nestjs/config';
import { DbModule } from './db/db.module';

@Module({
  imports: [UsersModule,DbModule, AuthModule, ProfilesModule,
    ConfigModule.forRoot({
        isGlobal: true,
      }),],
})
export class AppModule {}