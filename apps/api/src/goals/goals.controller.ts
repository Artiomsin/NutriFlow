import {
  Controller,
  Get,
  Post,
  Patch,
  Body,
  Query,
  UseGuards,
  Param,
  ParseUUIDPipe,
  BadRequestException,
} from '@nestjs/common';
import { GoalsService } from './goals.service';
import {
  updateGoalsSchema,
  goalsQuerySchema,
  goalsHistoryQuerySchema,
  progressQuerySchema,
  progressApplySchema,
  clearManualOverrideSchema,
  applySuggestionSchema,
  newCycleSchema,
} from './goals.schema';
import type {
  UpdateGoalsDto,
  GoalsQueryDto,
  GoalsHistoryQueryDto,
  ProgressQueryDto,
  ProgressApplyDto,
  ClearManualOverrideDto,
  ApplySuggestionDto,
  NewCycleDto,
} from './goals.schema';
import { ZodValidationPipe } from '../common/validation/zod-validation.pipe';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { User } from '../auth/decorators/user.decorator';
import type { AuthPayload } from '../auth/types/auth.types';
import { GoalPersonalizationService } from './personalization/goal-personalization.service';
import { GoalsProgressService } from './goals-progress.service';

@Controller('goals')
@UseGuards(JwtAuthGuard)
export class GoalsController {
  constructor(
    private readonly goalsService: GoalsService,
    private readonly personalizationService: GoalPersonalizationService,
    private readonly progressService: GoalsProgressService,
  ) {}

  @Get()
  findMe(
    @User() user: AuthPayload,
    @Query(new ZodValidationPipe(goalsQuerySchema))
    query: GoalsQueryDto,
  ) {
    return this.goalsService.findByUserId(user.userId, query.date, query.tz);
  }

  @Get('preview')
  preview(@User() user: AuthPayload) {
    return this.goalsService.preview(user.userId);
  }

  @Patch()
  update(
    @User() user: AuthPayload,
    @Body(new ZodValidationPipe(updateGoalsSchema)) data: UpdateGoalsDto,
  ) {
    return this.goalsService.update(user.userId, data);
  }

  @Post('calculate')
  calculate(@User() user: AuthPayload) {
    return this.goalsService.calculate(user.userId, undefined, {
      reason: 'recalculate_requested',
      trigger: 'recalculate_requested',
    });
  }

  @Post('reset-to-automatic')
  resetToAutomatic(@User() user: AuthPayload) {
    return this.goalsService.resetToAutomatic(user.userId);
  }

  @Post('apply-suggestion')
  applySuggestion(
    @User() user: AuthPayload,
    @Body(new ZodValidationPipe(applySuggestionSchema))
    body?: ApplySuggestionDto,
  ) {
    return this.goalsService.applySuggestion(user.userId, body?.metrics);
  }

  @Post('dismiss-suggestion')
  dismissSuggestion(@User() user: AuthPayload) {
    return this.goalsService.dismissSuggestion(user.userId);
  }

  @Post('clear-manual-overrides')
  clearManualOverrides(@User() user: AuthPayload) {
    return this.goalsService.clearManualOverrides(user.userId);
  }

  @Post('clear-manual-override')
  clearManualOverride(
    @User() user: AuthPayload,
    @Body(new ZodValidationPipe(clearManualOverrideSchema))
    body: ClearManualOverrideDto,
  ) {
    return this.goalsService.clearManualOverride(user.userId, body.metric);
  }

  @Post('new-cycle')
  startNewCycle(
    @User() user: AuthPayload,
    @Body(new ZodValidationPipe(newCycleSchema)) body: NewCycleDto,
  ) {
    return this.goalsService.startNewCycle(user.userId, body);
  }

  @Post('personalize')
  personalize(@User() user: AuthPayload) {
    return this.personalizationService.personalize(user.userId);
  }

  @Get('personalization')
  personalizationState(@User() user: AuthPayload) {
    return this.personalizationService.getPersonalizationState(user.userId);
  }

  @Post('personalization/:id/accept')
  acceptRecommendation(
    @User() user: AuthPayload,
    @Param('id', new ParseUUIDPipe()) id: string,
  ) {
    return this.personalizationService.acceptRecommendation(user.userId, id);
  }

  @Post('personalization/:id/dismiss')
  dismissRecommendation(
    @User() user: AuthPayload,
    @Param('id', new ParseUUIDPipe()) id: string,
  ) {
    return this.personalizationService.dismissRecommendation(user.userId, id);
  }

  @Get('progress')
  progress(
    @User() user: AuthPayload,
    @Query(new ZodValidationPipe(progressQuerySchema))
    query: ProgressQueryDto,
  ) {
    return this.progressService.getWeeklyProgress(user.userId, query.days);
  }

  @Post('progress/apply')
  async applyProgressAdjustment(
    @User() user: AuthPayload,
    @Query(new ZodValidationPipe(progressQuerySchema))
    query: ProgressQueryDto,
    @Body(new ZodValidationPipe(progressApplySchema))
    body?: ProgressApplyDto,
  ) {
    const days = body?.days ?? query.days ?? 14;
    const progress = await this.progressService.getWeeklyProgress(
      user.userId,
      days,
    );
    const adjustment = progress.recommendation.suggestedAdjustment;
    if (!adjustment || progress.recommendation.nothingToChange) {
      throw new BadRequestException('No progress adjustment to apply');
    }
    if (adjustment.diff.length === 0) {
      throw new BadRequestException('No goal changes to apply');
    }

    // If client passed explicit metrics (confirmable apply), verify they match
    // the currently computed adjustment to avoid applying stale/conflicting data.
    if (body?.metrics) {
      const expected = adjustment.metrics;
      const keys = Object.keys(expected) as (keyof typeof expected)[];
      const mismatches = keys.filter(
        (k) => (body.metrics?.[k] ?? null) !== (expected[k] ?? null),
      );
      if (mismatches.length > 0) {
        throw new BadRequestException({
          message:
            'Provided metrics do not match current progress adjustment. Refresh progress and retry.',
          mismatches,
        });
      }
    }

    return this.goalsService.applyGoalMetrics(user.userId, adjustment.metrics, {
      reason: `progress_${progress.recommendation.action}`,
      appliedBasis: {
        fromProgress: true,
        period: progress.period,
        status: progress.status,
        reason: progress.reason,
        action: progress.recommendation.action,
        confirmedMetrics: body?.metrics ? true : false,
      },
    });
  }

  @Get('history')
  goalHistory(
    @User() user: AuthPayload,
    @Query(new ZodValidationPipe(goalsHistoryQuerySchema))
    query: GoalsHistoryQueryDto,
  ) {
    return this.goalsService.getHistory(user.userId, query);
  }
}
