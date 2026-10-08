import {
  Controller,
  Get,
  Post,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  UsePipes,
  ParseUUIDPipe,
} from '@nestjs/common';

import { WaterTrackingService } from './water-tracking.service';

import {
  createWaterEntrySchema,
  optionalDateQuerySchema,
  requiredDateQuerySchema,
} from './water-tracking.schema';
import type {
  CreateWaterEntryDto,
  OptionalDateQueryDto,
  RequiredDateQueryDto,
} from './water-tracking.schema';

import { ZodValidationPipe } from '../common/validation/zod-validation.pipe';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { User } from '../auth/decorators/user.decorator';
import type { AuthPayload } from '../auth/types/auth.types';


@Controller('water-tracking')
export class WaterTrackingController {
  constructor(private readonly waterService: WaterTrackingService) {}

  @UseGuards(JwtAuthGuard)
  @Post()
  create(
    @User() user: AuthPayload,
    @Body(new ZodValidationPipe(createWaterEntrySchema)) data: CreateWaterEntryDto,
  ) {
    return this.waterService.create(user.userId, data);
  }

  @UseGuards(JwtAuthGuard)
  @Get('today')
  findToday(
    @User() user: AuthPayload,
    @Query(new ZodValidationPipe(optionalDateQuerySchema)) query: OptionalDateQueryDto,
  ) {
    return this.waterService.getToday(user.userId, query.date);
  }

  @UseGuards(JwtAuthGuard)
  @Get()
  getByDate(
    @User() user: AuthPayload,
    @Query(new ZodValidationPipe(requiredDateQuerySchema)) query: RequiredDateQueryDto,
  ) {
    return this.waterService.getByDate(user.userId, query.date);
  }

  @UseGuards(JwtAuthGuard)
  @Delete(':id')
  delete(
    @User() user: AuthPayload,
    @Param('id', ParseUUIDPipe) id: string,
    @Query('date') date?: string,
  ) {
    return this.waterService.delete(user.userId, id, date);
  }
}
