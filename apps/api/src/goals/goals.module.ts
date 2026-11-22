import { Module } from '@nestjs/common';
import { GoalsService } from './goals.service';
import { GoalsController } from './goals.controller';
import { GoalPersonalizationService } from './personalization/goal-personalization.service';
import { GoalsProgressService } from './goals-progress.service';

@Module({
  providers: [GoalsService, GoalPersonalizationService, GoalsProgressService],
  controllers: [GoalsController],
  exports: [GoalsService],
})
export class GoalsModule {}
