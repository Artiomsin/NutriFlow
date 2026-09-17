import { Module } from '@nestjs/common';
import { ProfilesService } from './profiles.service';
import { ProfilesController } from './profiles.controller';
import { GoalsModule } from '../goals/goals.module';
import { WeightLogsModule } from '../weight-logs/weight-logs.module';

@Module({
  imports: [GoalsModule, WeightLogsModule],
  controllers: [ProfilesController],
  providers: [ProfilesService],
})
export class ProfilesModule {}
