import { Module } from '@nestjs/common';
import { SleepService } from './sleep.service';
import { SleepController } from './sleep.controller';

@Module({
  controllers: [SleepController],
  providers: [SleepService],
})
export class SleepModule {}
