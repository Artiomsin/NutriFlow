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
  HttpStatus,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';

import { JwtAuthGuard } from '../auth/jwt.guard';
import { User } from '../auth/decorators/user.decorator';
import type { AuthPayload } from '../auth/types/auth.types';

import { FoodService } from './food.service';
import { UploadService } from '../upload/upload.service';
import { FoodAnalysisService } from './food-analysis.service';
import { BarcodeLookupService } from './barcode/barcode-lookup.service';
import { gtinValidationProblem } from './barcode/gtin';
import { RateLimit, UserRateLimit } from '../rate-limit/rate-limit.decorators';
import { UserRateLimitGuard } from '../rate-limit/user-rate-limit.guard';
import { env } from '../config/env';

import {
  createFoodEntrySchema,
  updateFoodEntrySchema,
  createFoodSchema,
  createFoodServingSchema,
  updateFoodServingSchema,
  createFoodCategorySchema,
  updateFoodCategorySchema,
  searchFoodQuerySchema,
  optionalDateQuerySchema,
  requiredDateQuerySchema,
  bulkUpdateFoodCategorySchema,
  getFoodsQuerySchema,
} from './food.schema';
import { ZodValidationPipe } from '../common/validation/zod-validation.pipe';
import {
  ProblemDetailsException,
  ProblemType,
} from '../common/http/problem-details';
import type {
  CreateFoodEntryDto,
  UpdateFoodEntryDto,
  CreateFoodDto,
  CreateFoodServingDto,
  UpdateFoodServingDto,
  CreateFoodCategoryDto,
  UpdateFoodCategoryDto,
  SearchFoodQueryDto,
  OptionalDateQueryDto,
  RequiredDateQueryDto,
  BulkUpdateFoodCategoryDto,
  GetFoodsQueryDto,
} from './food.schema';

@Controller()
@UseGuards(JwtAuthGuard)
export class FoodController {
  constructor(
    private readonly foodService: FoodService,
    private readonly foodAnalysisService: FoodAnalysisService,
    private readonly uploadService: UploadService,
    private readonly barcodeLookup: BarcodeLookupService,
  ) {}

  // ── Upload ───────────────────────────────────────────────────

  private assertImage(file?: {
    buffer: Buffer;
    mimetype: string;
    originalname: string;
    size: number;
  }) {
    if (!file) throw new BadRequestException('File is required');
    const allowedMimeTypes = new Set([
      'image/jpeg',
      'image/png',
      'image/webp',
      'image/heic',
      'image/heif',
    ]);
    if (!allowedMimeTypes.has(file.mimetype)) {
      throw new BadRequestException(
        'Only JPEG, PNG, WebP, and HEIC images are allowed',
      );
    }
    return file;
  }

  @Post('food/upload')
  @RateLimit('upload-ip', env.RATE_LIMIT_UPLOAD, 60_000)
  @UserRateLimit({ scope: 'upload', limit: env.RATE_LIMIT_UPLOAD, ttl: 60_000 })
  @UseGuards(UserRateLimitGuard)
  @UseInterceptors(
    FileInterceptor('file', { limits: { fileSize: 5 * 1024 * 1024 } }),
  )
  async upload(
    @User() user: AuthPayload,
    @UploadedFile()
    file:
      | { buffer: Buffer; mimetype: string; originalname: string; size: number }
      | undefined,
  ) {
    const f = this.assertImage(file);

    const upload = await this.uploadService.upload(user.userId, f.buffer);
    return { uploadId: upload.id, url: `/api/uploads/${upload.id}` };
  }

  @Post('food/analyze')
  @RateLimit('analyze-ip', env.RATE_LIMIT_ANALYZE, 60_000)
  @UserRateLimit({
    scope: 'analyze',
    limit: env.RATE_LIMIT_ANALYZE,
    ttl: 60_000,
  })
  @UseGuards(UserRateLimitGuard)
  @UseInterceptors(
    FileInterceptor('file', { limits: { fileSize: 5 * 1024 * 1024 } }),
  )
  async analyze(
    @User() user: AuthPayload,
    @UploadedFile()
    file:
      | { buffer: Buffer; mimetype: string; originalname: string; size: number }
      | undefined,
  ) {
    const f = this.assertImage(file);

    return this.foodAnalysisService.analyzePhoto(user.userId, f);
  }

  // ── Food Category Routes ────────────────────────────────────

  @Get('food-categories')
  getCategories(@User() user: AuthPayload) {
    return this.foodService.getCategories(user.userId);
  }

  @Post('food-categories')
  createCategory(
    @User() user: AuthPayload,
    @Body(new ZodValidationPipe(createFoodCategorySchema))
    data: CreateFoodCategoryDto,
  ) {
    return this.foodService.createCategory(user.userId, data);
  }

  @Patch('food-categories/:id')
  updateCategory(
    @User() user: AuthPayload,
    @Param('id', ParseUUIDPipe) id: string,
    @Body(new ZodValidationPipe(updateFoodCategorySchema))
    data: UpdateFoodCategoryDto,
  ) {
    return this.foodService.updateCategory(user.userId, id, data);
  }

  @Delete('food-categories/:id')
  removeCategory(
    @User() user: AuthPayload,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.foodService.removeCategory(user.userId, id);
  }

  // ── Food Entry Routes ────────────────────────────────────────

  @Post('food-entry')
  create(
    @User() user: AuthPayload,
    @Body(new ZodValidationPipe(createFoodEntrySchema))
    data: CreateFoodEntryDto,
  ) {
    return this.foodService.create(user.userId, data);
  }

  @Get('food-entry/today')
  getToday(
    @User() user: AuthPayload,
    @Query(new ZodValidationPipe(optionalDateQuerySchema))
    query: OptionalDateQueryDto,
  ) {
    return this.foodService.getToday(user.userId, query.date);
  }

  @Get('food-entry')
  getByDate(
    @User() user: AuthPayload,
    @Query(new ZodValidationPipe(requiredDateQuerySchema))
    query: RequiredDateQueryDto,
  ) {
    return this.foodService.getByDate(user.userId, query.date);
  }

  @Delete('food-entry/:id')
  delete(
    @User() user: AuthPayload,
    @Param('id', ParseUUIDPipe) id: string,
    @Query(new ZodValidationPipe(optionalDateQuerySchema))
    query: OptionalDateQueryDto,
  ) {
    return this.foodService.delete(user.userId, id, query.date);
  }

  @Patch('food-entry/:id')
  update(
    @User() user: AuthPayload,
    @Param('id', ParseUUIDPipe) id: string,
    @Body(new ZodValidationPipe(updateFoodEntrySchema))
    data: UpdateFoodEntryDto,
  ) {
    return this.foodService.update(user.userId, id, data);
  }

  // ── Food Catalog Routes ──────────────────────────────────────

  @Patch('foods/bulk/category')
  bulkUpdateCategory(
    @User() user: AuthPayload,
    @Body(new ZodValidationPipe(bulkUpdateFoodCategorySchema))
    data: BulkUpdateFoodCategoryDto,
  ) {
    return this.foodService.bulkUpdateCategory(user.userId, data);
  }

  @Get('foods')
  getAll(
    @User() user: AuthPayload,
    @Query(new ZodValidationPipe(getFoodsQuerySchema))
    query: GetFoodsQueryDto,
  ) {
    return this.foodService.getAll(query, user.userId);
  }

  @Get('foods/search')
  search(
    @User() user: AuthPayload,
    @Query(new ZodValidationPipe(searchFoodQuerySchema))
    query: SearchFoodQueryDto,
  ) {
    return this.foodService.search(query, user.userId);
  }

  @Get('foods/popular')
  getPopular(@User() user: AuthPayload) {
    return this.foodService.getPopular(user.userId);
  }

  @Get('foods/barcode/:barcode')
  @RateLimit('barcode-ip', env.RATE_LIMIT_BARCODE, 60_000)
  @UserRateLimit({
    scope: 'barcode',
    limit: env.RATE_LIMIT_BARCODE,
    ttl: 60_000,
  })
  @UseGuards(UserRateLimitGuard)
  async getByBarcode(
    @User() user: AuthPayload,
    @Param('barcode') barcode: string,
  ) {
    const result = await this.barcodeLookup.lookup(barcode, user.userId);

    if (result.invalid) {
      const problem = gtinValidationProblem(barcode);
      throw new ProblemDetailsException({
        type: ProblemType.validationFailed,
        title: 'Validation failed',
        status: HttpStatus.BAD_REQUEST,
        detail: problem.detail,
        fieldErrors: [{ field: 'barcode', code: problem.code }],
      });
    }

    if (!result.found || !result.product) {
      // A caller that scanned a real barcode should not be told the product
      // does not exist when we simply could not reach a provider.
      if (result.unavailable) {
        throw new ProblemDetailsException({
          type: ProblemType.serviceUnavailable,
          title: 'Service unavailable',
          status: HttpStatus.SERVICE_UNAVAILABLE,
          detail:
            'Barcode lookup is temporarily unavailable, please try again later',
        });
      }
      throw new ProblemDetailsException({
        type: ProblemType.notFound,
        title: 'Not found',
        status: HttpStatus.NOT_FOUND,
        detail: 'Food with this barcode was not found',
      });
    }

    const product = result.product;
    let servings = product.servings ?? [];

    // The cached payload is a snapshot. Portions are editable by the user, so
    // for a cache hit they are re-read from the database instead of being
    // served stale for up to the cache TTL.
    if (result.cached && product.id) {
      try {
        const fresh = await this.foodService.getById(product.id, user.userId);
        servings = fresh.servings ?? [];
      } catch {
        // The product is no longer visible: keep the cached snapshot.
      }
    }

    return {
      ...product,
      servings,
      provider: result.provider,
      cached: result.cached ?? false,
    };
  }

  @Get('foods/:id')
  getById(@User() user: AuthPayload, @Param('id', ParseUUIDPipe) id: string) {
    return this.foodService.getById(id, user.userId);
  }

  @Post('foods/:id/select')
  select(@User() user: AuthPayload, @Param('id', ParseUUIDPipe) id: string) {
    return this.foodService.trackSelection(user.userId, id);
  }

  // ── Servings (portions of a product) ─────────────────────────

  @Post('foods/:id/servings')
  addServing(
    @User() user: AuthPayload,
    @Param('id', ParseUUIDPipe) id: string,
    @Body(new ZodValidationPipe(createFoodServingSchema))
    data: CreateFoodServingDto,
  ) {
    return this.foodService.addServing(user.userId, id, data);
  }

  @Patch('foods/:id/servings/:servingId')
  updateServing(
    @User() user: AuthPayload,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('servingId', ParseUUIDPipe) servingId: string,
    @Body(new ZodValidationPipe(updateFoodServingSchema))
    data: UpdateFoodServingDto,
  ) {
    return this.foodService.updateServing(user.userId, id, servingId, data);
  }

  @Delete('foods/:id/servings/:servingId')
  removeServing(
    @User() user: AuthPayload,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('servingId', ParseUUIDPipe) servingId: string,
  ) {
    return this.foodService.removeServing(user.userId, id, servingId);
  }

  @Post('foods')
  createFood(
    @User() user: AuthPayload,
    @Body(new ZodValidationPipe(createFoodSchema)) data: CreateFoodDto,
  ) {
    return this.foodService.createFood(user.userId, data);
  }
}
