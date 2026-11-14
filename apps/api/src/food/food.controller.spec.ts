import { describe, expect, it, mock } from 'bun:test';
import { BadRequestException } from '@nestjs/common';
import { GUARDS_METADATA } from '@nestjs/common/constants';

import { JwtAuthGuard } from '../auth/jwt.guard';
import type { AuthPayload } from '../auth/types/auth.types';
import type { UploadService } from '../upload/upload.service';
import { FoodController } from './food.controller';
import type { FoodAnalysisService } from './food-analysis.service';
import type { FoodService } from './food.service';
import type { BarcodeLookupService } from './barcode/barcode-lookup.service';
import { ProblemType } from '../common/http/problem-details';

type UploadedImage = {
  buffer: Buffer;
  mimetype: string;
  originalname: string;
  size: number;
};

function setup() {
  const foodService = {
    create: mock(async () => ({ id: 'entry-1' })),
    getToday: mock(async () => []),
    getByDate: mock(async () => []),
    delete: mock(async () => ({ message: 'Deleted' })),
    update: mock(async () => ({ id: 'entry-1' })),
    getCategories: mock(async () => []),
    createCategory: mock(async () => ({ id: 'cat-1' })),
    updateCategory: mock(async () => ({ id: 'cat-1' })),
    removeCategory: mock(async () => ({ id: 'cat-1' })),
    getAll: mock(async () => []),
    search: mock(async () => ({ foods: [] })),
    getPopular: mock(async () => []),
    getByBarcode: mock(async () => null),
    getById: mock(async () => ({ id: 'food-1' })),
    trackSelection: mock(async () => ({ ok: true })),
    createFood: mock(async () => ({ id: 'food-1' })),
  };
  const foodAnalysisService = { analyzePhoto: mock(async () => []) };
  const uploadService = { upload: mock(async () => ({ id: 'upload-1' })) };
  const barcodeLookup = {
    lookup: mock(async () => ({ found: false, provider: 'none' })),
  };
  const controller = new FoodController(
    foodService as unknown as FoodService,
    foodAnalysisService as unknown as FoodAnalysisService,
    uploadService as unknown as UploadService,
    barcodeLookup as unknown as BarcodeLookupService,
  );

  return {
    controller,
    foodService,
    foodAnalysisService,
    uploadService,
    barcodeLookup,
  };
}

const user = { userId: 'user-1', sessionId: 'session-1' } as AuthPayload;
const image: UploadedImage = {
  buffer: Buffer.from('img'),
  mimetype: 'image/png',
  originalname: 'a.png',
  size: 3,
};

describe('FoodController guards', () => {
  it('applies JwtAuthGuard at the class level', () => {
    const guards = Reflect.getMetadata(GUARDS_METADATA, FoodController);
    expect(guards).toContain(JwtAuthGuard);
  });
});

describe('FoodController upload / analyze', () => {
  it('rejects an upload without a file', () => {
    const { controller } = setup();
    expect(controller.upload(user, undefined)).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });

  it('rejects an unsupported mime type', () => {
    const { controller } = setup();
    expect(
      controller.upload(user, { ...image, mimetype: 'application/pdf' }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('uploads a valid image and returns its private upload id', async () => {
    const { controller, uploadService } = setup();
    const result = await controller.upload(user, image);
    expect(uploadService.upload).toHaveBeenCalledWith('user-1', image.buffer);
    expect(result).toEqual({
      uploadId: 'upload-1',
      url: '/api/uploads/upload-1',
    });
  });

  it('delegates a valid image to the analysis service', async () => {
    const { controller, foodAnalysisService } = setup();
    await controller.analyze(user, image);
    expect(foodAnalysisService.analyzePhoto).toHaveBeenCalledWith(
      'user-1',
      image,
    );
  });
});

describe('FoodController food entries', () => {
  it('creates an entry for the current user', async () => {
    const { controller, foodService } = setup();
    const dto = { name: 'Banana', calories: 89 };
    await controller.create(user, dto);
    expect(foodService.create).toHaveBeenCalledWith('user-1', dto);
  });

  it('passes the date to getToday', async () => {
    const { controller, foodService } = setup();
    await controller.getToday(user, { date: '2026-01-01' });
    expect(foodService.getToday).toHaveBeenCalledWith('user-1', '2026-01-01');
  });

  it('passes the date to getByDate', async () => {
    const { controller, foodService } = setup();
    await controller.getByDate(user, { date: '2026-01-02' });
    expect(foodService.getByDate).toHaveBeenCalledWith('user-1', '2026-01-02');
  });

  it('passes id and date to delete', async () => {
    const { controller, foodService } = setup();
    await controller.delete(user, 'entry-1', { date: '2026-01-03' });
    expect(foodService.delete).toHaveBeenCalledWith(
      'user-1',
      'entry-1',
      '2026-01-03',
    );
  });

  it('updates an entry', async () => {
    const { controller, foodService } = setup();
    const dto = { grams: 150 };
    await controller.update(user, 'entry-1', dto);
    expect(foodService.update).toHaveBeenCalledWith('user-1', 'entry-1', dto);
  });
});

describe('FoodController categories', () => {
  it('lists categories for the caller', async () => {
    const { controller, foodService } = setup();
    await controller.getCategories(user);
    expect(foodService.getCategories).toHaveBeenCalledWith('user-1');
  });

  it('creates a category for the caller', async () => {
    const { controller, foodService } = setup();
    const dto = { name: 'Fruit' };
    await controller.createCategory(user, dto);
    expect(foodService.createCategory).toHaveBeenCalledWith('user-1', dto);
  });

  it('updates a category for the caller', async () => {
    const { controller, foodService } = setup();
    const dto = { name: 'Fruit' };
    await controller.updateCategory(user, 'cat-1', dto);
    expect(foodService.updateCategory).toHaveBeenCalledWith(
      'user-1',
      'cat-1',
      dto,
    );
  });

  it('removes a category for the caller', async () => {
    const { controller, foodService } = setup();
    await controller.removeCategory(user, 'cat-1');
    expect(foodService.removeCategory).toHaveBeenCalledWith('user-1', 'cat-1');
  });
});

describe('FoodController catalog', () => {
  it('forwards pagination for getAll', async () => {
    const { controller, foodService } = setup();
    const query = { limit: 50, offset: 0 };
    await controller.getAll(user, query);
    expect(foodService.getAll).toHaveBeenCalledWith(query, 'user-1');
  });

  it('forwards a category filter for getAll', async () => {
    const { controller, foodService } = setup();
    const query = {
      categoryId: '4cf8c276-1f4d-4b6e-8994-f42b94a181ac',
      limit: 20,
      offset: 0,
    };
    await controller.getAll(user, query);
    expect(foodService.getAll).toHaveBeenCalledWith(query, 'user-1');
  });

  it('forwards the uncategorized filter for getAll', async () => {
    const { controller, foodService } = setup();
    const query = { categoryId: 'null', limit: 20, offset: 10 };
    await controller.getAll(user, query);
    expect(foodService.getAll).toHaveBeenCalledWith(query, 'user-1');
  });

  it('searches with the current user', async () => {
    const { controller, foodService } = setup();
    const query = { q: 'apple', limit: 20, offset: 0 };
    await controller.search(user, query);
    expect(foodService.search).toHaveBeenCalledWith(query, 'user-1');
  });

  it('lists popular foods', async () => {
    const { controller, foodService } = setup();
    await controller.getPopular(user);
    expect(foodService.getPopular).toHaveBeenCalledWith('user-1');
  });

  it('looks up a barcode', async () => {
    const { controller, barcodeLookup } = setup();
    const barcodeResult = {
      found: true,
      provider: 'local-database',
      product: {
        id: 'food-1',
        name: 'Test Product',
        barcode: '12345',
        caloriesPer100g: 100,
        source: 'system',
      },
      cached: false,
    };
    (barcodeLookup.lookup as any).mockResolvedValueOnce(barcodeResult);
    const result = await controller.getByBarcode(user, '12345');
    expect(barcodeLookup.lookup).toHaveBeenCalledWith('12345', 'user-1');
    expect(result.provider).toBe('local-database');
    expect(result.name).toBe('Test Product');
  });

  it('refreshes servings for a cached barcode hit', async () => {
    const { controller, foodService, barcodeLookup } = setup();
    const cachedResult = {
      found: true,
      provider: 'local-database',
      cached: true,
      product: {
        id: 'food-1',
        name: 'Test Product',
        barcode: '4006381333931',
        caloriesPer100g: 100,
        source: 'system',
        servings: [{ id: 'old', name: 'Old portion', grams: 10 }],
      },
    };
    (barcodeLookup.lookup as any).mockResolvedValueOnce(cachedResult);
    (foodService.getById as any).mockResolvedValueOnce({
      id: 'food-1',
      servings: [{ id: 'new', name: 'New portion', grams: 25 }],
    });

    const result = await controller.getByBarcode(user, '4006381333931');

    expect(foodService.getById).toHaveBeenCalledWith('food-1', 'user-1');
    expect(result.servings).toEqual([
      { id: 'new', name: 'New portion', grams: 25 },
    ]);
    expect(result.cached).toBe(true);
  });

  it('answers 503 when a barcode provider could not be reached', async () => {
    const { controller, barcodeLookup } = setup();
    (barcodeLookup.lookup as any).mockResolvedValueOnce({
      found: false,
      provider: 'none',
      unavailable: true,
    });

    await expect(
      controller.getByBarcode(user, '4006381333931'),
    ).rejects.toMatchObject({
      response: {
        type: ProblemType.serviceUnavailable,
        status: 503,
        detail:
          'Barcode lookup is temporarily unavailable, please try again later',
      },
    });
  });

  it('returns a validation problem with a barcode field error', async () => {
    const { controller, barcodeLookup } = setup();
    (barcodeLookup.lookup as any).mockResolvedValueOnce({ invalid: true });

    await expect(controller.getByBarcode(user, '')).rejects.toMatchObject({
      response: {
        type: ProblemType.validationFailed,
        status: 400,
        fieldErrors: [{ field: 'barcode', code: 'REQUIRED' }],
      },
    });
  });

  it('returns a not-found problem with detail for an unknown barcode', async () => {
    const { controller, barcodeLookup } = setup();
    (barcodeLookup.lookup as any).mockResolvedValueOnce({
      found: false,
      provider: 'none',
    });

    await expect(
      controller.getByBarcode(user, '4006381333931'),
    ).rejects.toMatchObject({
      response: {
        type: ProblemType.notFound,
        status: 404,
        detail: 'Food with this barcode was not found',
      },
    });
  });

  it('looks up a food by id', async () => {
    const { controller, foodService } = setup();
    await controller.getById(user, 'food-1');
    expect(foodService.getById).toHaveBeenCalledWith('food-1', 'user-1');
  });

  it('tracks a selection', async () => {
    const { controller, foodService } = setup();
    await controller.select(user, 'food-1');
    expect(foodService.trackSelection).toHaveBeenCalledWith('user-1', 'food-1');
  });

  it('creates a catalog food', async () => {
    const { controller, foodService } = setup();
    const dto = { name: 'Oats', caloriesPer100g: 389 };
    await controller.createFood(user, dto);
    expect(foodService.createFood).toHaveBeenCalledWith('user-1', dto);
  });
});
