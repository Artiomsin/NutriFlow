import {
  Controller,
  Get,
  Post,
  Delete,
  Body,
  Query,
  Param,
  UseGuards,
} from '@nestjs/common';
import { WeightLogsService } from './weight-logs.service';
import {
  createWeightLogSchema,
  listWeightLogsSchema,
} from './weight-logs.schema';
import type {
  CreateWeightLogDto,
  ListWeightLogsDto,
} from './weight-logs.schema';
import { ZodValidationPipe } from '../common/validation/zod-validation.pipe';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { User } from '../auth/decorators/user.decorator';
import type { AuthPayload } from '../auth/types/auth.types';

@Controller('weight-logs')
@UseGuards(JwtAuthGuard)
export class WeightLogsController {
  constructor(private readonly weightLogsService: WeightLogsService) {}

  @Post()
  record(
    @User() user: AuthPayload,
    @Body(new ZodValidationPipe(createWeightLogSchema)) data: CreateWeightLogDto,
  ) {
    return this.weightLogsService.record(user.userId, data);
  }

  @Get()
  list(
    @User() user: AuthPayload,
    @Query(new ZodValidationPipe(listWeightLogsSchema)) query: ListWeightLogsDto,
  ) {
    return this.weightLogsService.findByRange(user.userId, query);
  }

  @Delete(':date')
  remove(@User() user: AuthPayload, @Param('date') date: string) {
    return this.weightLogsService.remove(user.userId, date);
  }
}