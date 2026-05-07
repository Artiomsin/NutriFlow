import { Test, TestingModule } from '@nestjs/testing';
import { WaterTrackingService } from './water-tracking.service';

describe('WaterTrackingService', () => {
  let service: WaterTrackingService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [WaterTrackingService],
    }).compile();

    service = module.get<WaterTrackingService>(WaterTrackingService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });
});
