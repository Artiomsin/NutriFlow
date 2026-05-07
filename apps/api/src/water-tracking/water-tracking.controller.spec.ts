import { Test, TestingModule } from '@nestjs/testing';
import { WaterTrackingController } from './water-tracking.controller';
import { WaterTrackingService } from './water-tracking.service';

describe('WaterTrackingController', () => {
  let controller: WaterTrackingController;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [WaterTrackingController],
      providers: [WaterTrackingService],
    }).compile();

    controller = module.get<WaterTrackingController>(WaterTrackingController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });
});
