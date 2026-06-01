import {
  Controller,
  Get,
  Query,
  UseGuards,
} from '@nestjs/common';
import { AnalyticsService } from './analytics.service';
import { rangeQuerySchema } from './analytics.schema';
import type { RangeQueryDto } from './analytics.schema';
import { ZodValidationPipe } from '../common/validation/zod-validation.pipe';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { User } from '../auth/decorators/user.decorator';
import type { AuthPayload } from '../auth/types/auth.types';
@Controller('analytics')
@UseGuards(JwtAuthGuard)
export class AnalyticsController {
  constructor(private readonly analyticsService: AnalyticsService) {}
  @Get('week')
  getWeek(@User() user: AuthPayload) {
    return this.analyticsService.getAnalytics(user.userId, 'week');
  }
  @Get('month')
  getMonth(@User() user: AuthPayload) {
    return this.analyticsService.getAnalytics(user.userId, 'month');
  }
  @Get('custom')
  getCustom(
    @User() user: AuthPayload,
    @Query(new ZodValidationPipe(rangeQuerySchema)) query: RangeQueryDto,
  ) {
    return this.analyticsService.getCustomRange(user.userId, query.from, query.to);
  }
}