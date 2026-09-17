import { Module } from '@nestjs/common';
import { GoalsService } from './goals.service';
import { GoalsController } from './goals.controller';
import { DataCollectionService } from './personalization/data-collection.service';
import { GoalPersonalizationService } from './personalization/goal-personalization.service';

@Module({
  providers: [GoalsService, DataCollectionService, GoalPersonalizationService],
  controllers: [GoalsController],
  exports: [GoalsService],
})
export class GoalsModule {}
