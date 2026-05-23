import {
  Controller, Get, Post, Patch,
  Body, UseGuards,
} from '@nestjs/common';
import { GoalsService } from './goals.service';
import { updateGoalsSchema } from './goals.schema';
import type { UpdateGoalsDto } from './goals.schema';
import { ZodValidationPipe } from '../common/validation/zod-validation.pipe';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { User } from '../auth/decorators/user.decorator';
import type { AuthPayload } from '../auth/types/auth.types';
@Controller('goals')
@UseGuards(JwtAuthGuard)
export class GoalsController {
  constructor(private readonly goalsService: GoalsService) {}
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
}