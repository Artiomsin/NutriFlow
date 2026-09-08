import { Controller, Get, Post, Delete, Body, Query, UseGuards } from '@nestjs/common';

import { WorkoutsService } from './workouts.service';
import { syncWorkoutsSchema, historyQuerySchema, deleteMissingSchema } from './workouts.schema';
import type { SyncWorkoutsDto, HistoryQueryDto, DeleteMissingDto } from './workouts.schema';

import { ZodValidationPipe } from '../common/validation/zod-validation.pipe';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { User } from '../auth/decorators/user.decorator';
import type { AuthPayload } from '../auth/types/auth.types';

@Controller('workouts')
export class WorkoutsController {
  constructor(private readonly workoutsService: WorkoutsService) {}

  @UseGuards(JwtAuthGuard)
  @Post('sync')
  sync(
    @User() user: AuthPayload,
    @Body(new ZodValidationPipe(syncWorkoutsSchema)) dto: SyncWorkoutsDto,
  ) {
    return this.workoutsService.sync(user.userId, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Get()
  getHistory(
    @User() user: AuthPayload,
    @Query(new ZodValidationPipe(historyQuerySchema)) query: HistoryQueryDto,
  ) {
    return this.workoutsService.getHistory(
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
    return this.workoutsService.deleteMissing(user.userId, dto.startDate, dto.healthKitWorkoutIds);
  }
}