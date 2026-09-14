import { Module } from '@nestjs/common';
import { WeightLogsService } from './weight-logs.service';
import { WeightLogsController } from './weight-logs.controller';

@Module({
  providers: [WeightLogsService],
  controllers: [WeightLogsController],
  exports: [WeightLogsService],
})
export class WeightLogsModule {}