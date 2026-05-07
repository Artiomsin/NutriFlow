import { Module } from '@nestjs/common';
import { WaterTrackingService } from './water-tracking.service';
import { WaterTrackingController } from './water-tracking.controller';

@Module({
  controllers: [WaterTrackingController],
  providers: [WaterTrackingService],
})
export class WaterTrackingModule {}
