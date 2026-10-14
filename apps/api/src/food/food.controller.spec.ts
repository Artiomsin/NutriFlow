import { describe, expect, it, mock } from 'bun:test';
import { BadRequestException } from '@nestjs/common';
import { GUARDS_METADATA } from '@nestjs/common/constants';

import { JwtAuthGuard } from '../auth/jwt.guard';
import type { AuthPayload } from '../auth/types/auth.types';
import type { UploadService } from '../upload/upload.service';
import { FoodController } from './food.controller';
import type { FoodAnalysisService } from './food-analysis.service';
import type { FoodService } from './food.service';

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
    getAll: mock(async () => []),
    search: mock(async () => ({ foods: [] })),
    getPopular: mock(async () => []),
    getByBarcode: mock(async () => null),
    getById: mock(async () => ({ id: 'food-1' })),
    trackSelection: mock(async () => ({ ok: true })),
    createFood: mock(async () => ({ id: 'food-1' })),
  };
  const foodAnalysisService = { analyzePhoto: mock(async () => []) };
  const uploadService = { upload: mock(async () => 'https://cdn/x.webp') };

  const controller = new FoodController(
    foodService as unknown as FoodService,
    foodAnalysisService as unknown as FoodAnalysisService,
    uploadService as unknown as UploadService,
  );

  return { controller, foodService, foodAnalysisService, uploadService };
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
    expect(controller.upload(undefined)).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });

  it('rejects an unsupported mime type', () => {
    const { controller } = setup();
    expect(
      controller.upload({ ...image, mimetype: 'application/pdf' }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('uploads a valid image and returns its url', async () => {
    const { controller, uploadService } = setup();
    const result = await controller.upload(image);
    expect(uploadService.upload).toHaveBeenCalledWith(image.buffer);
    expect(result).toEqual({ url: 'https://cdn/x.webp' });
  });

  it('delegates analysis to the analysis service', async () => {
    const { controller, foodAnalysisService } = setup();
    await controller.analyze(image);
    expect(foodAnalysisService.analyzePhoto).toHaveBeenCalledWith(image);
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
    await controller.delete(user, 'entry-1', '2026-01-03');
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
  it('lists categories', async () => {
    const { controller, foodService } = setup();
    await controller.getCategories();
    expect(foodService.getCategories).toHaveBeenCalled();
  });

  it('creates a category', async () => {
    const { controller, foodService } = setup();
    const dto = { name: 'Fruit' };
    await controller.createCategory(dto);
    expect(foodService.createCategory).toHaveBeenCalledWith(dto);
  });
});

describe('FoodController catalog', () => {
  it('uses default limit and offset for getAll', async () => {
    const { controller, foodService } = setup();
    await controller.getAll(user);
    expect(foodService.getAll).toHaveBeenCalledWith(50, 0, 'user-1');
  });

  it('clamps an oversized limit to 200', async () => {
    const { controller, foodService } = setup();
    await controller.getAll(user, '500');
    expect(foodService.getAll).toHaveBeenCalledWith(200, 0, 'user-1');
  });

  it('falls back to 50 on an unparsable limit', async () => {
    const { controller, foodService } = setup();
    await controller.getAll(user, 'abc');
    expect(foodService.getAll).toHaveBeenCalledWith(50, 0, 'user-1');
  });

  it('clamps a negative offset to 0', async () => {
    const { controller, foodService } = setup();
    await controller.getAll(user, '10', '-5');
    expect(foodService.getAll).toHaveBeenCalledWith(10, 0, 'user-1');
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
    const { controller, foodService } = setup();
    await controller.getByBarcode(user, '12345');
    expect(foodService.getByBarcode).toHaveBeenCalledWith('12345', 'user-1');
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
