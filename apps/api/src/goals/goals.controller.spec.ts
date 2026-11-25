import { describe, expect, it, mock } from 'bun:test';
import { GUARDS_METADATA } from '@nestjs/common/constants';

import { JwtAuthGuard } from '../auth/jwt.guard';
import type { AuthPayload } from '../auth/types/auth.types';
import { GoalsController } from './goals.controller';
import type { GoalsService } from './goals.service';
import type { GoalPersonalizationService } from './personalization/goal-personalization.service';
import type { GoalsProgressService } from './goals-progress.service';

function setup() {
  const goalsService = {
    findByUserId: mock(async () => ({ userId: 'user-1' })),
    getHistory: mock(async () => ({ items: [], nextCursor: null })),
    update: mock(async () => ({ userId: 'user-1' })),
    calculate: mock(async () => ({ userId: 'user-1' })),
    resetToAutomatic: mock(async () => ({ userId: 'user-1' })),
    preview: mock(async () => ({ recommended: {} })),
    previewDraft: mock(async () => ({ recommended: {} })),
    applySuggestion: mock(async () => ({ userId: 'user-1' })),
    dismissSuggestion: mock(async () => ({ userId: 'user-1' })),
    clearManualOverrides: mock(async () => ({ userId: 'user-1' })),
    clearManualOverride: mock(async () => ({ userId: 'user-1' })),
    startNewCycle: mock(async () => ({ userId: 'user-1' })),
    applyGoalMetrics: mock(async () => ({ userId: 'user-1' })),
  };
  const personalizationService = {
    personalize: mock(async () => ({ status: 'insufficient_data' })),
    getPersonalizationState: mock(async () => ({ pending: null })),
    acceptRecommendation: mock(async () => ({ ok: true })),
    dismissRecommendation: mock(async () => ({ dismissed: true })),
  };
  const progressService = {
    getWeeklyProgress: mock(async () => ({
      status: 'insufficient_data',
      recommendation: {
        nothingToChange: true,
        action: 'collect_data',
        suggestedAdjustment: null,
      },
    })),
  };

  return {
    controller: new GoalsController(
      goalsService as unknown as GoalsService,
      personalizationService as unknown as GoalPersonalizationService,
      progressService as unknown as GoalsProgressService,
    ),
    goalsService,
    personalizationService,
    progressService,
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

    await controller.previewDraft({
      weight: 80,
      height: 180,
      age: 30,
      gender: 'male',
      goal: 'lose',
      activityLevel: 'medium',
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

    expect(goalsService.previewDraft).toHaveBeenCalledWith({
      weight: 80,
      height: 180,
      age: 30,
      gender: 'male',
      goal: 'lose',
      activityLevel: 'medium',
    });
    expect(goalsService.update).toHaveBeenCalledWith('user-1', {
      dailyCaloriesGoal: 2200,
    });
    expect(goalsService.calculate).toHaveBeenCalledWith('user-1', undefined, {
      reason: 'recalculate_requested',
      trigger: 'recalculate_requested',
    });
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

  it('delegates suggestion and manual-override actions', async () => {
    const { controller, goalsService } = setup();
    await controller.applySuggestion(user, {
      metrics: ['dailyCaloriesGoal'],
    } as any);
    await controller.dismissSuggestion(user);
    await controller.clearManualOverrides(user);
    await controller.clearManualOverride(user, {
      metric: 'dailyCaloriesGoal',
    } as any);

    expect(goalsService.applySuggestion).toHaveBeenCalledWith('user-1', [
      'dailyCaloriesGoal',
    ]);
    expect(goalsService.dismissSuggestion).toHaveBeenCalledWith('user-1');
    expect(goalsService.clearManualOverrides).toHaveBeenCalledWith('user-1');
    expect(goalsService.clearManualOverride).toHaveBeenCalledWith(
      'user-1',
      'dailyCaloriesGoal',
    );
  });

  it('delegates new cycle and progress', async () => {
    const { controller, goalsService, progressService } = setup();
    await controller.startNewCycle(user, { action: 'maintain' } as any);
    await controller.progress(user, { days: 14 } as any);

    expect(goalsService.startNewCycle).toHaveBeenCalledWith('user-1', {
      action: 'maintain',
    });
    expect(progressService.getWeeklyProgress).toHaveBeenCalledWith(
      'user-1',
      14,
    );
  });

  it('applies progress adjustment when metrics match current adjustment', async () => {
    const { controller, goalsService, progressService } = setup();
    progressService.getWeeklyProgress = mock(async () => ({
      status: 'slightly_off',
      reason: 'rate',
      period: { start: '2026-01-01', end: '2026-01-14', days: 14 },
      recommendation: {
        action: 'adjust_plan',
        nothingToChange: false,
        suggestedAdjustment: {
          metrics: { dailyCaloriesGoal: 2100 },
          diff: [{ metric: 'dailyCaloriesGoal', from: 2200, to: 2100 }],
        },
      },
    })) as any;

    await controller.applyProgressAdjustment(
      user,
      { days: 14 } as any,
      { metrics: { dailyCaloriesGoal: 2100 } } as any,
    );

    expect(goalsService.applyGoalMetrics).toHaveBeenCalled();
  });

  it('delegates preview to GoalsService', async () => {
    const { controller, goalsService } = setup();
    await controller.preview(user);
    expect(goalsService.preview).toHaveBeenCalledWith('user-1');
  });

  it('throws when progress apply has no actionable adjustment', async () => {
    const { controller, progressService } = setup();
    progressService.getWeeklyProgress = mock(async () => ({
      status: 'on_track',
      recommendation: { nothingToChange: true, suggestedAdjustment: null },
    })) as any;

    await expect(
      controller.applyProgressAdjustment(user, { days: 14 } as any, undefined),
    ).rejects.toThrow('No progress adjustment to apply');
  });

  it('throws on stale progress apply metrics mismatch', async () => {
    const { controller, progressService } = setup();
    progressService.getWeeklyProgress = mock(async () => ({
      status: 'slightly_off',
      reason: 'rate',
      period: { start: '2026-01-01', end: '2026-01-14', days: 14 },
      recommendation: {
        action: 'adjust_plan',
        nothingToChange: false,
        suggestedAdjustment: {
          metrics: { dailyCaloriesGoal: 2100 },
          diff: [{ metric: 'dailyCaloriesGoal', from: 2200, to: 2100 }],
        },
      },
    })) as any;

    await expect(
      controller.applyProgressAdjustment(
        user,
        { days: 14 } as any,
        { metrics: { dailyCaloriesGoal: 9999 } } as any,
      ),
    ).rejects.toThrow();
  });

  it('applies progress adjustment without confirmation payload when action exists', async () => {
    const { controller, goalsService, progressService } = setup();
    progressService.getWeeklyProgress = mock(async () => ({
      status: 'off_track',
      reason: 'rate',
      period: { start: '2026-01-01', end: '2026-01-14', days: 14 },
      recommendation: {
        action: 'slow_down',
        nothingToChange: false,
        suggestedAdjustment: {
          metrics: { dailyCaloriesGoal: 2300 },
          diff: [{ metric: 'dailyCaloriesGoal', from: 2200, to: 2300 }],
        },
      },
    })) as any;

    await controller.applyProgressAdjustment(
      user,
      { days: 14 } as any,
      undefined,
    );

    expect(goalsService.applyGoalMetrics).toHaveBeenCalledWith(
      'user-1',
      { dailyCaloriesGoal: 2300 },
      expect.objectContaining({ reason: 'progress_slow_down' }),
    );
  });

  it('delegates applySuggestion with undefined metrics', async () => {
    const { controller, goalsService } = setup();
    await controller.applySuggestion(user, undefined as any);
    expect(goalsService.applySuggestion).toHaveBeenCalledWith(
      'user-1',
      undefined,
    );
  });
});
