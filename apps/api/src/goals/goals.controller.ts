import {
  Controller,
  Get,
  Post,
  Patch,
  Body,
  UseGuards,
  Param,
  ParseUUIDPipe,
} from '@nestjs/common';
import { GoalsService } from './goals.service';
import { updateGoalsSchema } from './goals.schema';
import type { UpdateGoalsDto } from './goals.schema';
import { ZodValidationPipe } from '../common/validation/zod-validation.pipe';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { User } from '../auth/decorators/user.decorator';
import type { AuthPayload } from '../auth/types/auth.types';
import { GoalPersonalizationService } from './personalization/goal-personalization.service';
@Controller('goals')
@UseGuards(JwtAuthGuard)
export class GoalsController {
  constructor(
    private readonly goalsService: GoalsService,
    private readonly personalizationService: GoalPersonalizationService,
  ) {}
  @Get()
  findMe(@User() user: AuthPayload) {
    return this.goalsService.findByUserId(user.userId);
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
    return this.goalsService.calculate(user.userId);
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

  @Get('history')
  goalHistory(@User() user: AuthPayload) {
    return this.personalizationService.getGoalHistory(user.userId);
  }
}
