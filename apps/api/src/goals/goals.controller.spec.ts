import { describe, expect, it, mock } from 'bun:test';
import { GUARDS_METADATA } from '@nestjs/common/constants';

import { JwtAuthGuard } from '../auth/jwt.guard';
import type { AuthPayload } from '../auth/types/auth.types';
import { GoalsController } from './goals.controller';
import type { GoalsService } from './goals.service';
import type { GoalPersonalizationService } from './personalization/goal-personalization.service';

function setup() {
  const goalsService = {
    findByUserId: mock(async () => ({ userId: 'user-1' })),
    getHistory: mock(async () => ({ items: [], nextCursor: null })),
    update: mock(async () => ({ userId: 'user-1' })),
    calculate: mock(async () => ({ userId: 'user-1' })),
    resetToAutomatic: mock(async () => ({ userId: 'user-1' })),
  };
  const personalizationService = {
    personalize: mock(async () => ({ status: 'insufficient_data' })),
    getPersonalizationState: mock(async () => ({ pending: null })),
    acceptRecommendation: mock(async () => ({ ok: true })),
    dismissRecommendation: mock(async () => ({ dismissed: true })),
  };

  return {
    controller: new GoalsController(
      goalsService as unknown as GoalsService,
      personalizationService as unknown as GoalPersonalizationService,
    ),
    goalsService,
    personalizationService,
  };
}

const user = { userId: 'user-1', sessionId: 's-1' } as AuthPayload;
const recId = '11111111-1111-4111-8111-111111111111';

describe('GoalsController', () => {
  it('is guarded by JwtAuthGuard', () => {
    const guards = Reflect.getMetadata(GUARDS_METADATA, GoalsController);
    expect(guards).toContain(JwtAuthGuard);
  });

  it('delegates goal reads and writes to GoalsService', async () => {
    const { controller, goalsService } = setup();

    await controller.findMe(user, {});
    await controller.findMe(user, {
      date: '2026-11-08',
      tz: 'Europe/Moscow',
    });

    await controller.update(user, { dailyCaloriesGoal: 2200 });
    await controller.calculate(user);
    await controller.resetToAutomatic(user);
    await controller.goalHistory(user, { limit: 20 });
    await controller.goalHistory(user, {
      date: '2026-11-08',
      tz: 'Europe/Moscow',
      limit: 20,
    });

    expect(goalsService.findByUserId).toHaveBeenNthCalledWith(
      1,
      'user-1',
      undefined,
      undefined,
    );
    expect(goalsService.findByUserId).toHaveBeenNthCalledWith(
      2,
      'user-1',
      '2026-11-08',
      'Europe/Moscow',
    );

    expect(goalsService.update).toHaveBeenCalledWith('user-1', {
      dailyCaloriesGoal: 2200,
    });
    expect(goalsService.calculate).toHaveBeenCalledWith('user-1');
    expect(goalsService.resetToAutomatic).toHaveBeenCalledWith('user-1');
    expect(goalsService.getHistory).toHaveBeenNthCalledWith(1, 'user-1', {
      limit: 20,
    });
    expect(goalsService.getHistory).toHaveBeenNthCalledWith(2, 'user-1', {
      date: '2026-11-08',
      tz: 'Europe/Moscow',
      limit: 20,
    });
  });

  it('delegates personalization to GoalPersonalizationService', async () => {
    const { controller, personalizationService } = setup();
    await controller.personalize(user);
    await controller.personalizationState(user);
    await controller.acceptRecommendation(user, recId);
    await controller.dismissRecommendation(user, recId);

    expect(personalizationService.personalize).toHaveBeenCalledWith('user-1');
    expect(personalizationService.getPersonalizationState).toHaveBeenCalledWith(
      'user-1',
    );
    expect(personalizationService.acceptRecommendation).toHaveBeenCalledWith(
      'user-1',
      recId,
    );
    expect(personalizationService.dismissRecommendation).toHaveBeenCalledWith(
      'user-1',
      recId,
    );
  });
});
