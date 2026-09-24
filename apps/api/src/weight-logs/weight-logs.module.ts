import { Module } from '@nestjs/common';
import { WeightLogsService } from './weight-logs.service';
import { WeightLogsController } from './weight-logs.controller';
import { GoalsModule } from '../goals/goals.module';

@Module({
  imports: [GoalsModule],
  providers: [WeightLogsService],
  controllers: [WeightLogsController],
  exports: [WeightLogsService],
})
export class WeightLogsModule {}
