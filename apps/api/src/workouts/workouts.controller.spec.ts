import { describe, expect, it, mock } from 'bun:test';
import { GUARDS_METADATA } from '@nestjs/common/constants';

import { JwtAuthGuard } from '../auth/jwt.guard';
import type { AuthPayload } from '../auth/types/auth.types';
import { WorkoutsController } from './workouts.controller';
import type { WorkoutsService } from './workouts.service';

function setup() {
  const workoutsService = {
    sync: mock(async () => ({ synced: 0 })),
    getHistory: mock(async () => ({ total: 0, workouts: [] })),
    deleteMissing: mock(async () => ({ deleted: 0 })),
  };

  return {
    controller: new WorkoutsController(
      workoutsService as unknown as WorkoutsService,
    ),
    workoutsService,
  };
}

const user = { userId: 'user-1', sessionId: 's-1' } as AuthPayload;

describe('WorkoutsController', () => {
  it('is guarded by JwtAuthGuard on every route', () => {
    for (const method of ['sync', 'getHistory', 'deleteMissing'] as const) {
      const guards = Reflect.getMetadata(
        GUARDS_METADATA,
        WorkoutsController.prototype[method],
      ) as unknown[] | undefined;
      expect(guards).toContain(JwtAuthGuard);
    }
  });

  it('delegates sync with the current user id', async () => {
    const { controller, workoutsService } = setup();
    const dto = {
      workouts: [
        {
          healthKitWorkoutId: 'HK-0001',
          type: 'running',
          startDate: '2026-01-01T10:00:00.000Z',
          endDate: '2026-01-01T10:45:00.000Z',
          localDate: '2026-01-01',
          durationSeconds: 2_700,
        },
      ],
    };

    await controller.sync(user, dto);

    expect(workoutsService.sync).toHaveBeenCalledWith('user-1', dto);
  });

  it('delegates getHistory with the pagination window', async () => {
    const { controller, workoutsService } = setup();

    await controller.getHistory(user, {
      from: '2026-01-01',
      to: '2026-01-31',
      limit: 25,
      offset: 5,
    });

    expect(workoutsService.getHistory).toHaveBeenCalledWith(
      'user-1',
      '2026-01-01',
      '2026-01-31',
      25,
      5,
    );
  });

  it('delegates deleteMissing with the window and kept workout ids', async () => {
    const { controller, workoutsService } = setup();

    await controller.deleteMissing(user, {
      startDate: '2026-01-01T00:00:00.000Z',
      endDate: '2026-01-31T00:00:00.000Z',
      healthKitWorkoutIds: ['HK-0001'],
    });

    expect(workoutsService.deleteMissing).toHaveBeenCalledWith(
      'user-1',
      '2026-01-01T00:00:00.000Z',
      '2026-01-31T00:00:00.000Z',
      ['HK-0001'],
    );
  });
});
