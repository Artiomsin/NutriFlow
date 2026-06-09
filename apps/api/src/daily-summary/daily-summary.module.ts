import { Module } from '@nestjs/common';
import { DailySummaryService } from './daily-summary.service';
import { DailySummaryController } from './daily-summary.controller';

@Module({
  controllers: [DailySummaryController],
  providers: [DailySummaryService],
  exports: [DailySummaryService],
})
export class DailySummaryModule {}
