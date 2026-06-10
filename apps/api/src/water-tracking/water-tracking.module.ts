import { Module } from '@nestjs/common';
import { WaterTrackingService } from './water-tracking.service';
import { WaterTrackingController } from './water-tracking.controller';
import { DailySummaryModule } from '../daily-summary/daily-summary.module';

@Module({
  imports: [DailySummaryModule],
  controllers: [WaterTrackingController],
  providers: [WaterTrackingService],
})
export class WaterTrackingModule {}
