import { describe, expect, it, mock } from 'bun:test';
import { GUARDS_METADATA } from '@nestjs/common/constants';

import { JwtAuthGuard } from '../auth/jwt.guard';
import type { AuthPayload } from '../auth/types/auth.types';
import { ActivityController } from './activity.controller';
import type { ActivityService } from './activity.service';

function setup() {
  const activityService = {
    sync: mock(async () => []),
    getToday: mock(async () => ({ steps: 0 })),
    getRange: mock(async () => []),
  };

  return {
    controller: new ActivityController(
      activityService as unknown as ActivityService,
    ),
    activityService,
  };
}

const user = { userId: 'user-1', sessionId: 's-1' } as AuthPayload;

describe('ActivityController', () => {
  it('is guarded by JwtAuthGuard on every route', () => {
    for (const method of ['sync', 'getToday', 'getRange'] as const) {
      const guards = Reflect.getMetadata(
        GUARDS_METADATA,
        ActivityController.prototype[method],
      ) as unknown[] | undefined;
      expect(guards).toContain(JwtAuthGuard);
    }
  });

  it('delegates sync with the current user id', async () => {
    const { controller, activityService } = setup();
    const dto = { entries: [{ date: '2026-01-01', steps: 100 }] };

    await controller.sync(user, dto);

    expect(activityService.sync).toHaveBeenCalledWith('user-1', dto);
  });

  it('delegates getToday with and without a date', async () => {
    const { controller, activityService } = setup();

    await controller.getToday(user, { date: '2026-01-05' });
    await controller.getToday(user, {});

    expect(activityService.getToday).toHaveBeenNthCalledWith(
      1,
      'user-1',
      '2026-01-05',
    );
    expect(activityService.getToday).toHaveBeenNthCalledWith(
      2,
      'user-1',
      undefined,
    );
  });

  it('delegates getRange with the from/to bounds', async () => {
    const { controller, activityService } = setup();

    await controller.getRange(user, { from: '2026-01-01', to: '2026-01-31' });

    expect(activityService.getRange).toHaveBeenCalledWith(
      'user-1',
      '2026-01-01',
      '2026-01-31',
    );
  });
});
