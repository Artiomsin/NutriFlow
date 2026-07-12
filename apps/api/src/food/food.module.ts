import { Module } from '@nestjs/common';
import { FoodService } from './food.service';
import { FoodController } from './food.controller';
import { DailySummaryModule } from '../daily-summary/daily-summary.module';
import { UploadModule } from '../upload/upload.module';

@Module({
  imports: [DailySummaryModule, UploadModule],
  controllers: [FoodController],
  providers: [FoodService],
})
export class FoodModule {}
