import { Test, TestingModule } from '@nestjs/testing';
import { DailySummaryController } from './daily-summary.controller';
import { DailySummaryService } from './daily-summary.service';

describe('DailySummaryController', () => {
  let controller: DailySummaryController;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [DailySummaryController],
      providers: [DailySummaryService],
    }).compile();

    controller = module.get<DailySummaryController>(DailySummaryController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });
});
