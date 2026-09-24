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
  Req,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';

import { JwtAuthGuard } from '../auth/jwt.guard';
import { User } from '../auth/decorators/user.decorator';
import type { AuthPayload } from '../auth/types/auth.types';

import { FoodService } from './food.service';
import { UploadService } from '../upload/upload.service';
import { FoodAnalysisService } from './food-analysis.service';
import { FoodRateLimitService } from './food-rate-limit.service';

import {
  createFoodEntrySchema,
  updateFoodEntrySchema,
  createFoodSchema,
  createFoodCategorySchema,
  searchFoodQuerySchema,
  optionalDateQuerySchema,
  requiredDateQuerySchema,
} from './food.schema';
import { ZodValidationPipe } from '../common/validation/zod-validation.pipe';
import type {
  CreateFoodEntryDto,
  UpdateFoodEntryDto,
  CreateFoodDto,
  CreateFoodCategoryDto,
  SearchFoodQueryDto,
  OptionalDateQueryDto,
  RequiredDateQueryDto,
} from './food.schema';


@Controller()
@UseGuards(JwtAuthGuard)
export class FoodController {
  constructor(
    private readonly foodService: FoodService,
    private readonly foodAnalysisService: FoodAnalysisService,
    private readonly uploadService: UploadService,
    private readonly foodRateLimitService: FoodRateLimitService,
  ) {}

  // ── Upload ───────────────────────────────────────────────────

  private assertImage(file?: { buffer: Buffer; mimetype: string; originalname: string; size: number }) {
    if (!file) throw new BadRequestException('File is required');
    const allowedMimeTypes = new Set([
      'image/jpeg',
      'image/png',
      'image/webp',
      'image/heic',
      'image/heif',
    ]);
    if (!allowedMimeTypes.has(file.mimetype)) {
      throw new BadRequestException('Only JPEG, PNG, WebP, and HEIC images are allowed');
    }
    return file;
  }

  @Post('food/upload')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 5 * 1024 * 1024 } }))
  async upload(
    @UploadedFile() file: { buffer: Buffer; mimetype: string; originalname: string; size: number } | undefined,
    @User() user: AuthPayload,
    @Req() request: { ip?: string; socket?: { remoteAddress?: string } },
  ) {
    await this.foodRateLimitService.checkUpload(this.clientIp(request), user.userId);
    const f = this.assertImage(file);

    const url = await this.uploadService.upload(f.buffer, f.mimetype);
    return { url };
  }

  @Post('food/analyze')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 5 * 1024 * 1024 } }))
  async analyze(
    @UploadedFile() file: { buffer: Buffer; mimetype: string; originalname: string; size: number } | undefined,
    @User() user: AuthPayload,
    @Req() request: { ip?: string; socket?: { remoteAddress?: string } },
  ) {
    await this.foodRateLimitService.checkAnalyze(this.clientIp(request), user.userId);
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
  getToday(
    @User() user: AuthPayload,
    @Query(new ZodValidationPipe(optionalDateQuerySchema)) query: OptionalDateQueryDto,
  ) {
    return this.foodService.getToday(user.userId, query.date);
  }

  @Get('food-entry')
  getByDate(
    @User() user: AuthPayload,
    @Query(new ZodValidationPipe(requiredDateQuerySchema)) query: RequiredDateQueryDto,
  ) {
    return this.foodService.getByDate(user.userId, query.date);
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
    @Req() request: { ip?: string; socket?: { remoteAddress?: string } },
  ) {
    return this.searchFood(query, user.userId, request);
  }

  @Get('foods/popular')
  getPopular(@User() user: AuthPayload) {
    return this.foodService.getPopular(user.userId);
  }

  @Get('foods/barcode/:barcode')
  getByBarcode(@User() user: AuthPayload, @Param('barcode') barcode: string) {
    return this.foodService.getByBarcode(barcode, user.userId);
  }

  @Get('foods/:id')
  getById(@User() user: AuthPayload, @Param('id', ParseUUIDPipe) id: string) {
    return this.foodService.getById(id, user.userId);
  }

  @Post('foods/:id/select')
  select(
    @User() user: AuthPayload,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.foodService.trackSelection(user.userId, id);
  }

  @Post('foods')
  createFood(
    @User() user: AuthPayload,
    @Body(new ZodValidationPipe(createFoodSchema)) data: CreateFoodDto,
  ) {
    return this.foodService.createFood(user.userId, data);
  }

  private async searchFood(
    query: SearchFoodQueryDto,
    userId: string,
    request: { ip?: string; socket?: { remoteAddress?: string } },
  ) {
    await this.foodRateLimitService.checkSearch(this.clientIp(request), userId);
    return this.foodService.search(query, userId);
  }

  private clientIp(request: { ip?: string; socket?: { remoteAddress?: string } }): string {
    return request.ip ?? request.socket?.remoteAddress ?? 'unknown';
  }
}
