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
    update: mock(async () => ({ userId: 'user-1' })),
    calculate: mock(async () => ({ userId: 'user-1' })),
    resetToAutomatic: mock(async () => ({ userId: 'user-1' })),
  };
  const personalizationService = {
    personalize: mock(async () => ({ status: 'insufficient_data' })),
    getPersonalizationState: mock(async () => ({ pending: null })),
    acceptRecommendation: mock(async () => ({ ok: true })),
    dismissRecommendation: mock(async () => ({ dismissed: true })),
    getGoalHistory: mock(async () => []),
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
    await controller.findMe(user);
    await controller.update(user, { dailyCaloriesGoal: 2200 });
    await controller.calculate(user);
    await controller.resetToAutomatic(user);

    expect(goalsService.findByUserId).toHaveBeenCalledWith('user-1');
    expect(goalsService.update).toHaveBeenCalledWith('user-1', {
      dailyCaloriesGoal: 2200,
    });
    expect(goalsService.calculate).toHaveBeenCalledWith('user-1');
    expect(goalsService.resetToAutomatic).toHaveBeenCalledWith('user-1');
  });

  it('delegates personalization to GoalPersonalizationService', async () => {
    const { controller, personalizationService } = setup();
    await controller.personalize(user);
    await controller.personalizationState(user);
    await controller.goalHistory(user);
    await controller.acceptRecommendation(user, recId);
    await controller.dismissRecommendation(user, recId);

    expect(personalizationService.personalize).toHaveBeenCalledWith('user-1');
    expect(personalizationService.getPersonalizationState).toHaveBeenCalledWith(
      'user-1',
    );
    expect(personalizationService.getGoalHistory).toHaveBeenCalledWith(
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
