import { describe, expect, it, mock } from 'bun:test';
import { GUARDS_METADATA } from '@nestjs/common/constants';

import { JwtAuthGuard } from '../auth/jwt.guard';
import type { AuthPayload } from '../auth/types/auth.types';
import { SleepController } from './sleep.controller';
import type { SleepService } from './sleep.service';

function setup() {
  const sleepService = {
    sync: mock(async () => ({ synced: 0 })),
    getHistory: mock(async () => ({ total: 0, nights: [] })),
    deleteMissing: mock(async () => ({ deleted: 0 })),
  };

  return {
    controller: new SleepController(sleepService as unknown as SleepService),
    sleepService,
  };
}

const user = { userId: 'user-1', sessionId: 's-1' } as AuthPayload;

describe('SleepController', () => {
  it('is guarded by JwtAuthGuard on every route', () => {
    for (const method of ['sync', 'getHistory', 'deleteMissing'] as const) {
      const guards = Reflect.getMetadata(
        GUARDS_METADATA,
        SleepController.prototype[method],
      ) as unknown[] | undefined;
      expect(guards).toContain(JwtAuthGuard);
    }
  });

  it('delegates sync with the current user id', async () => {
    const { controller, sleepService } = setup();
    const dto = {
      nights: [
        {
          startDate: '2026-01-01T22:30:00.000Z',
          endDate: '2026-01-02T06:30:00.000Z',
          localDate: '2026-01-02',
        },
      ],
    };

    await controller.sync(user, dto);

    expect(sleepService.sync).toHaveBeenCalledWith('user-1', dto);
  });

  it('delegates getHistory with the pagination window', async () => {
    const { controller, sleepService } = setup();

    await controller.getHistory(user, {
      from: '2026-01-01',
      to: '2026-01-31',
      limit: 50,
      offset: 10,
    });

    expect(sleepService.getHistory).toHaveBeenCalledWith(
      'user-1',
      '2026-01-01',
      '2026-01-31',
      50,
      10,
    );
  });

  it('delegates deleteMissing with the window and kept start dates', async () => {
    const { controller, sleepService } = setup();
    const kept = ['2026-01-02T22:30:00.000Z'];

    await controller.deleteMissing(user, {
      startDate: '2026-01-01T00:00:00.000Z',
      endDate: '2026-01-31T00:00:00.000Z',
      keptStartDates: kept,
    });

    expect(sleepService.deleteMissing).toHaveBeenCalledWith(
      'user-1',
      '2026-01-01T00:00:00.000Z',
      '2026-01-31T00:00:00.000Z',
      kept,
    );
  });
});
