import { Module } from '@nestjs/common';
import { GoalsService } from './goals.service';
import { GoalsController } from './goals.controller';

@Module({
  providers: [GoalsService],
  controllers: [GoalsController]
})
export class GoalsModule {}
