import {
  Controller,
  Post,
  Get,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
} from '@nestjs/common';

import { JwtAuthGuard } from '../auth/jwt.guard';
import { User } from '../auth/decorators/user.decorator';
import type { AuthPayload } from '../auth/types/auth.types';

import { FoodService } from './food.service';
import {
  createFoodEntrySchema,
  createFoodSchema,
  createFoodCategorySchema,
  searchFoodQuerySchema,
} from './food.schema';
import { ZodValidationPipe } from '../common/validation/zod-validation.pipe';
import type {
  CreateFoodEntryDto,
  CreateFoodDto,
  CreateFoodCategoryDto,
  SearchFoodQueryDto,
} from './food.schema';


@Controller()
@UseGuards(JwtAuthGuard)
export class FoodController {
  constructor(private readonly foodService: FoodService) {}

  // ── Food Category Routes ────────────────────────────────────

  @Get('food-categories')
  getCategories() {
    return this.foodService.getCategories();
  }

  @Post('food-categories')
  createCategory(
    @Body(new ZodValidationPipe(createFoodCategorySchema)) data: CreateFoodCategoryDto,
  ) {
    return this.foodService.createCategory(data);
  }

  // ── Food Entry Routes ────────────────────────────────────────

  @Post('food-entry')
  create(
    @User() user: AuthPayload,
    @Body(new ZodValidationPipe(createFoodEntrySchema)) data: CreateFoodEntryDto,
  ) {
    return this.foodService.create(user.userId, data);
  }

  @Get('food-entry/today')
  getToday(@User() user: AuthPayload) {
    return this.foodService.getToday(user.userId);
  }

  @Get('food-entry')
  getByDate(@User() user: AuthPayload, @Query('date') date: string) {
    return this.foodService.getByDate(user.userId, date);
  }

  @Delete('food-entry/:id')
  delete(@User() user: AuthPayload, @Param('id') id: string) {
    return this.foodService.delete(user.userId, id);
  }

  // ── Food Catalog Routes ──────────────────────────────────────

  @Get('foods')
  getAll() {
    return this.foodService.getAll();
  }

  @Get('foods/search')
  search(
    @User() user: AuthPayload,
    @Query(new ZodValidationPipe(searchFoodQuerySchema)) query: SearchFoodQueryDto,
  ) {
    return this.foodService.search(user.userId, query);
  }

  @Get('foods/popular')
  getPopular(@User() user: AuthPayload) {
    return this.foodService.getPopular(user.userId);
  }

  @Get('foods/barcode/:barcode')
  getByBarcode(@Param('barcode') barcode: string) {
    return this.foodService.getByBarcode(barcode);
  }

  @Get('foods/:id')
  getById(@Param('id') id: string) {
    return this.foodService.getById(id);
  }

  @Post('foods')
  createFood(
    @User() user: AuthPayload,
    @Body(new ZodValidationPipe(createFoodSchema)) data: CreateFoodDto,
  ) {
    return this.foodService.createFood(user.userId, data);
  }
}

