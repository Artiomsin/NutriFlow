import { Module } from '@nestjs/common';
import { FoodService } from './food.service';
import { FoodController } from './food.controller';
import { DailySummaryModule } from '../daily-summary/daily-summary.module';
import { UploadModule } from '../upload/upload.module';
import { FoodAnalysisService } from './food-analysis.service';
import { AnalysisQuotaService } from './analysis-quota.service';
import { FoodMatcherService } from './food-matcher.service';
import { RateLimitModule } from '../rate-limit/rate-limit.module';

@Module({
  imports: [DailySummaryModule, UploadModule, RateLimitModule],
  controllers: [FoodController],
  providers: [
    FoodService,
    FoodAnalysisService,
    AnalysisQuotaService,
    FoodMatcherService,
  ],
})
export class FoodModule {}
