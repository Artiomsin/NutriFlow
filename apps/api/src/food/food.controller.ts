import {
  Controller,
  Post,
  Get,
  Delete,
  Body,
  Param,
  UseGuards,
} from '@nestjs/common';

import { JwtAuthGuard } from '../auth/jwt.guard';
import { User } from '../auth/decorators/user.decorator';
import type { AuthPayload } from '../auth/types/auth.types';

import { FoodService } from './food.service';
import { createFoodEntrySchema } from './food.schema';
import { ZodValidationPipe } from '../common/validation/zod-validation.pipe';
import type { CreateFoodEntryDto } from './food.schema';


@Controller('food-entry')
@UseGuards(JwtAuthGuard)
export class FoodController {
  constructor(private readonly foodService: FoodService) {}

  @Post()
  create(
    @User() user: AuthPayload,
    @Body(new ZodValidationPipe(createFoodEntrySchema)) data: CreateFoodEntryDto,
  ) {
    return this.foodService.create(user.userId, data);
  }

  @Get('today')
  getToday(@User() user: AuthPayload) {
    return this.foodService.getToday(user.userId);
  }

  @Delete(':id')
  delete(@User() user: AuthPayload, @Param('id') id: string) {
    return this.foodService.delete(user.userId, id);
  }
}