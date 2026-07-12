import {
  Controller,
  Get,
  Query,
  UseGuards,
  UsePipes,
} from '@nestjs/common';

import { DailySummaryService } from './daily-summary.service';

import { JwtAuthGuard } from '../auth/jwt.guard';
import { User } from '../auth/decorators/user.decorator';
import type { AuthPayload } from '../auth/types/auth.types';

import { ZodValidationPipe } from '../common/validation/zod-validation.pipe';

import {
  dateQuerySchema,
  rangeQuerySchema,
} from './daily-summary.schema';

import type {
  DateQueryDto,
  RangeQueryDto,
} from './daily-summary.schema';

@Controller('daily-summary')
@UseGuards(JwtAuthGuard)
export class DailySummaryController {
  constructor(
    private readonly dailySummaryService: DailySummaryService,
  ) {}

  @Get('today')
  findToday(@User() user: AuthPayload, @Query('date') date?: string) {
    return this.dailySummaryService.findToday(user.userId, date);
  }

  @Get()
  findByDate(
    @User() user: AuthPayload,
    @Query(new ZodValidationPipe(dateQuerySchema))
    query: DateQueryDto,
  ) {
    return this.dailySummaryService.findByDate(
      user.userId,
      query.date,
    );
  }

  @Get('dashboard')
  findTodayDashboard(@User() user: AuthPayload, @Query('date') date?: string) {
    return this.dailySummaryService.findTodayDashboard(user.userId, date);
  }

  @Get('range')
  findRange(
    @User() user: AuthPayload,
    @Query(new ZodValidationPipe(rangeQuerySchema))
    query: RangeQueryDto,
  ) {
    return this.dailySummaryService.findRange(
      user.userId,
      query.from,
      query.to,
    );
  }
}