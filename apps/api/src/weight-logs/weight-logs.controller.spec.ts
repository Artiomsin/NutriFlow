import { describe, expect, it, mock } from 'bun:test';
import { GUARDS_METADATA } from '@nestjs/common/constants';

import { JwtAuthGuard } from '../auth/jwt.guard';
import type { AuthPayload } from '../auth/types/auth.types';
import { WeightLogsController } from './weight-logs.controller';
import type { WeightLogsService } from './weight-logs.service';

function setup() {
  const weightLogsService = {
    record: mock(async () => ({ userId: 'user-1' })),
    findByRange: mock(async () => []),
    remove: mock(async () => ({ userId: 'user-1' })),
  };

  return {
    controller: new WeightLogsController(
      weightLogsService as unknown as WeightLogsService,
    ),
    weightLogsService,
  };
}

const user = { userId: 'user-1', sessionId: 's-1' } as AuthPayload;

describe('WeightLogsController', () => {
  it('is guarded by JwtAuthGuard', () => {
    const guards = Reflect.getMetadata(GUARDS_METADATA, WeightLogsController);
    expect(guards).toContain(JwtAuthGuard);
  });

  it('delegates record, list and remove with the current user id', async () => {
    const { controller, weightLogsService } = setup();
    await controller.record(user, { weightKg: 70 });
    await controller.list(user, { from: '2026-01-01', to: '2026-01-31' });
    await controller.remove(user, { date: '2026-01-05' });

    expect(weightLogsService.record).toHaveBeenCalledWith('user-1', {
      weightKg: 70,
    });
    expect(weightLogsService.findByRange).toHaveBeenCalledWith('user-1', {
      from: '2026-01-01',
      to: '2026-01-31',
    });
    expect(weightLogsService.remove).toHaveBeenCalledWith(
      'user-1',
      '2026-01-05',
    );
  });
});
