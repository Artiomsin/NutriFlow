import { describe, expect, it, mock } from 'bun:test';
import { GUARDS_METADATA } from '@nestjs/common/constants';

import { JwtAuthGuard } from '../auth/jwt.guard';
import type { AuthPayload } from '../auth/types/auth.types';
import { WaterTrackingController } from './water-tracking.controller';
import type { WaterTrackingService } from './water-tracking.service';

function setup() {
  const waterService = {
    create: mock(async () => ({ id: 'water-1' })),
    getToday: mock(async () => []),
    getByDate: mock(async () => []),
    delete: mock(async () => ({ message: 'Deleted' })),
  };

  const controller = new WaterTrackingController(
    waterService as unknown as WaterTrackingService,
  );

  return { controller, waterService };
}

const user = { userId: 'user-1', sessionId: 'session-1' } as AuthPayload;

describe('WaterTrackingController guards', () => {
  it('guards every route with JwtAuthGuard', () => {
    for (const method of [
      'create',
      'findToday',
      'getByDate',
      'delete',
    ] as const) {
      const guards = Reflect.getMetadata(
        GUARDS_METADATA,
        WaterTrackingController.prototype[method],
      );
      expect(guards).toContain(JwtAuthGuard);
    }
  });
});

describe('WaterTrackingController', () => {
  it('creates an entry for the current user', async () => {
    const { controller, waterService } = setup();
    const dto = { amountMl: 500 };
    await controller.create(user, dto);
    expect(waterService.create).toHaveBeenCalledWith('user-1', dto);
  });

  it('passes the date to findToday', async () => {
    const { controller, waterService } = setup();
    await controller.findToday(user, { date: '2026-01-01' });
    expect(waterService.getToday).toHaveBeenCalledWith('user-1', '2026-01-01');
  });

  it('passes the date to getByDate', async () => {
    const { controller, waterService } = setup();
    await controller.getByDate(user, { date: '2026-01-02' });
    expect(waterService.getByDate).toHaveBeenCalledWith('user-1', '2026-01-02');
  });

  it('passes id and date to delete', async () => {
    const { controller, waterService } = setup();
    await controller.delete(user, 'water-1', '2026-01-03');
    expect(waterService.delete).toHaveBeenCalledWith(
      'user-1',
      'water-1',
      '2026-01-03',
    );
  });
});
