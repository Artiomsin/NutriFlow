import { Controller } from '@nestjs/common';
import { WaterTrackingService } from './water-tracking.service';

@Controller('water-tracking')
export class WaterTrackingController {
  constructor(private readonly waterTrackingService: WaterTrackingService) {}
}
