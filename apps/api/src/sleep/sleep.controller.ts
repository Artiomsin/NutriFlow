import { Controller, Get, Post, Delete, Body, Query, UseGuards } from '@nestjs/common';

import { SleepService } from './sleep.service';
import { syncSleepSchema, historyQuerySchema, deleteMissingSchema } from './sleep.schema';
import type { SyncSleepDto, HistoryQueryDto, DeleteMissingDto } from './sleep.schema';

import { ZodValidationPipe } from '../common/validation/zod-validation.pipe';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { User } from '../auth/decorators/user.decorator';
import type { AuthPayload } from '../auth/types/auth.types';

@Controller('sleep')
export class SleepController {
  constructor(private readonly sleepService: SleepService) {}

  @UseGuards(JwtAuthGuard)
  @Post('sync')
  sync(
    @User() user: AuthPayload,
    @Body(new ZodValidationPipe(syncSleepSchema)) dto: SyncSleepDto,
  ) {
    return this.sleepService.sync(user.userId, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Get()
  getHistory(
    @User() user: AuthPayload,
    @Query(new ZodValidationPipe(historyQuerySchema)) query: HistoryQueryDto,
  ) {
    return this.sleepService.getHistory(
      user.userId,
      query.from,
      query.to,
      query.limit,
      query.offset,
    );
  }

  @UseGuards(JwtAuthGuard)
  @Delete('missing')
  deleteMissing(
    @User() user: AuthPayload,
    @Body(new ZodValidationPipe(deleteMissingSchema)) dto: DeleteMissingDto,
  ) {
    return this.sleepService.deleteMissing(user.userId, dto.startDate, dto.startDates);
  }
}