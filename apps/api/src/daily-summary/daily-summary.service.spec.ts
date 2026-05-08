import { Test, TestingModule } from '@nestjs/testing';
import { DailySummaryService } from './daily-summary.service';

describe('DailySummaryService', () => {
  let service: DailySummaryService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [DailySummaryService],
    }).compile();

    service = module.get<DailySummaryService>(DailySummaryService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });
});
