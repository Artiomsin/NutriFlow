import { Module } from "@nestjs/common";
import { UsersModule } from './users/users.module';
import { AuthModule } from './auth/auth.module';
import { ProfilesModule } from './profiles/profiles.module';

@Module({
  imports: [UsersModule, AuthModule, ProfilesModule],
})
export class AppModule {}