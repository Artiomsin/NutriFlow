import { Controller, Get, Post, Body, Query, UseGuards } from '@nestjs/common';

import { ActivityService } from './activity.service';
import { syncActivitySchema } from './activity.schema';
import type { SyncActivityDto } from './activity.schema';

import { ZodValidationPipe } from '../common/validation/zod-validation.pipe';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { User } from '../auth/decorators/user.decorator';
import type { AuthPayload } from '../auth/types/auth.types';


@Controller('activity')
export class ActivityController { 
  constructor(private readonly activityService: ActivityService) {}

  @UseGuards(JwtAuthGuard)
  @Post('sync')
  sync(
      @User() user: AuthPayload,
      @Body(new ZodValidationPipe(syncActivitySchema)) dto: SyncActivityDto,
    ) {
      return this.activityService.sync(user.userId, dto);
    }

    @UseGuards(JwtAuthGuard)
      @Get('today')
      getToday(@User() user: AuthPayload, @Query('date') date?: string) {
        return this.activityService.getToday(user.userId, date);
    }

  @UseGuards(JwtAuthGuard)
  @Get('range')
  getRange(@User() user: AuthPayload, @Query('from') from: string, @Query('to') to: string) {
    return this.activityService.getRange(user.userId, from, to);
  }
  
}