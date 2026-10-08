import { Module } from '@nestjs/common';
import { FoodService } from './food.service';
import { FoodController } from './food.controller';
import { DailySummaryModule } from '../daily-summary/daily-summary.module';
import { UploadModule } from '../upload/upload.module';
import { FoodAnalysisService } from './food-analysis.service';
import { FoodMatcherService } from './food-matcher.service';

@Module({
  imports: [DailySummaryModule, UploadModule],
  controllers: [FoodController],
  providers: [FoodService, FoodAnalysisService, FoodMatcherService],
})
export class FoodModule {}
