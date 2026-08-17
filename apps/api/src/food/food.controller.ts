import {
  Controller,
  Post,
  Get,
  Patch,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  BadRequestException,
  ParseUUIDPipe,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';

import { JwtAuthGuard } from '../auth/jwt.guard';
import { User } from '../auth/decorators/user.decorator';
import type { AuthPayload } from '../auth/types/auth.types';

import { FoodService } from './food.service';
import { UploadService } from '../upload/upload.service';
import { FoodAnalysisService } from './food-analysis.service';

import {
  createFoodEntrySchema,
  updateFoodEntrySchema,
  createFoodSchema,
  createFoodCategorySchema,
  searchFoodQuerySchema,
} from './food.schema';
import { ZodValidationPipe } from '../common/validation/zod-validation.pipe';
import type {
  CreateFoodEntryDto,
  UpdateFoodEntryDto,
  CreateFoodDto,
  CreateFoodCategoryDto,
  SearchFoodQueryDto,
} from './food.schema';


@Controller()
@UseGuards(JwtAuthGuard)
export class FoodController {
  constructor(
    private readonly foodService: FoodService,
    private readonly foodAnalysisService: FoodAnalysisService,
    private readonly uploadService: UploadService,
  ) {}

  // ── Upload ───────────────────────────────────────────────────

  private assertImage(file?: { buffer: Buffer; mimetype: string; originalname: string; size: number }) {
    if (!file) throw new BadRequestException('File is required');
    if (!file.mimetype?.startsWith('image/')) {
      throw new BadRequestException('Only image files are allowed');
    }
    return file;
  }

  @Post('food/upload')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 5 * 1024 * 1024 } }))
  async upload(@UploadedFile() file?: { buffer: Buffer; mimetype: string; originalname: string; size: number }) {
    const f = this.assertImage(file);

    const url = await this.uploadService.upload(f.buffer, f.mimetype);
    return { url };
  }

  @Post('food/analyze')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 5 * 1024 * 1024 } }))
  async analyze(@UploadedFile() file?: { buffer: Buffer; mimetype: string; originalname: string; size: number }) {
    const f = this.assertImage(file);
    return this.foodAnalysisService.analyzePhoto(f);
  }

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
  getToday(@User() user: AuthPayload, @Query('date') date?: string) {
    return this.foodService.getToday(user.userId, date);
  }

  @Get('food-entry')
  getByDate(@User() user: AuthPayload, @Query('date') date: string) {
    return this.foodService.getByDate(user.userId, date);
  }

  @Delete('food-entry/:id')
  delete(
    @User() user: AuthPayload,
    @Param('id', ParseUUIDPipe) id: string,
    @Query('date') date?: string,
  ) {
    return this.foodService.delete(user.userId, id, date);
  }

  @Patch('food-entry/:id')
  update(
    @User() user: AuthPayload,
    @Param('id', ParseUUIDPipe) id: string,
    @Body(new ZodValidationPipe(updateFoodEntrySchema)) data: UpdateFoodEntryDto,
  ) {
    return this.foodService.update(user.userId, id, data);
  }

  // ── Food Catalog Routes ──────────────────────────────────────

  @Get('foods')
  getAll(
    @User() user: AuthPayload,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.foodService.getAll(
      limit ? Math.min(Math.max(parseInt(limit, 10) || 50, 1), 200) : 50,
      offset ? Math.max(parseInt(offset, 10) || 0, 0) : 0,
      user.userId,
    );
  }

  @Get('foods/search')
  search(
    @User() user: AuthPayload,
    @Query(new ZodValidationPipe(searchFoodQuerySchema)) query: SearchFoodQueryDto,
  ) {
    return this.foodService.search(query, user.userId);
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
  getById(@Param('id', ParseUUIDPipe) id: string) {
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

