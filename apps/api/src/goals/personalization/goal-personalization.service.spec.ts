import { describe, expect, it, mock } from 'bun:test';

import { GoalPersonalizationService } from './goal-personalization.service';
import type { GoalsProgressService } from '../goals-progress.service';
import type { Db } from '../../db/db';

type Progress = {
  status: 'on_track' | 'slightly_off' | 'off_track' | 'insufficient_data';
  reason: 'rate' | 'adherence' | 'both' | 'data';
  period: { start: string; end: string; days: number };
  appliedGoals: any;
  metrics: {
    loggedDaysCount: number;
    weighInsCount: number;
    activityDaysCount: number;
    workoutDaysCount: number;
    sleepNightsCount: number;
    calorieAdherence: number | null;
    proteinAdherence: number | null;
    actualRateKgPerWeek: number | null;
  };
  confidence: 'low' | 'medium' | 'high';
  recommendation: {
    action: 'none' | 'collect_data' | 'adjust_plan' | 'ease_plan' | 'slow_down';
    text: string;
    nothingToChange: boolean;
    suggestedAdjustment: null | {
      metrics: any;
      diff: Array<{ metric: string; from: number | null; to: number | null }>;
      note?: string;
      basis?: Record<string, unknown>;
      suggestedPlan?: any;
    };
  };
};

function makeProgress(overrides: Partial<Progress> = {}): Progress {
  const base: Progress = {
    status: 'slightly_off',
    reason: 'rate',
    period: { start: '2026-01-01', end: '2026-01-14', days: 14 },
    appliedGoals: { dailyCaloriesGoal: 2200 },
    metrics: {
      loggedDaysCount: 10,
      weighInsCount: 5,
      activityDaysCount: 8,
      workoutDaysCount: 3,
      sleepNightsCount: 8,
      calorieAdherence: 0.8,
      proteinAdherence: 0.9,
      actualRateKgPerWeek: -0.2,
    },
    confidence: 'medium',
    recommendation: {
      action: 'ease_plan',
      text: 'Ease plan',
      nothingToChange: false,
      suggestedAdjustment: {
        metrics: { dailyCaloriesGoal: 2300 },
        diff: [{ metric: 'dailyCaloriesGoal', from: 2200, to: 2300 }],
      },
    },
  };
  return {
    ...base,
    ...overrides,
    metrics: { ...base.metrics, ...(overrides.metrics ?? {}) },
    recommendation: {
      ...base.recommendation,
      ...(overrides.recommendation ?? {}),
    },
  };
}

function makeDb(options: {
  selectQueue?: any[][];
  insertQueue?: any[][];
  updateQueue?: any[][];
}) {
  const selectQueue = [...(options.selectQueue ?? [])];
  const insertQueue = [...(options.insertQueue ?? [])];
  const updateQueue = [...(options.updateQueue ?? [])];

  const nextSelect = () => (selectQueue.length ? selectQueue.shift()! : []);
  const nextInsert = () => (insertQueue.length ? insertQueue.shift()! : []);
  const nextUpdate = () => (updateQueue.length ? updateQueue.shift()! : []);

  const makeSelectChain = () => {
    const result = nextSelect();
    const chain: any = {};
    chain.from = mock(() => chain);
    chain.where = mock(() => chain);
    chain.orderBy = mock(() => chain);
    chain.limit = mock(async () => result);
    chain.then = (resolve: any, reject: any) =>
      Promise.resolve(result).then(resolve, reject);
    return chain;
  };

  const makeInsertChain = () => {
    const result = nextInsert();
    const chain: any = {};
    chain.values = mock(() => chain);
    chain.returning = mock(async () => result);
    chain.then = (resolve: any, reject: any) =>
      Promise.resolve(result).then(resolve, reject);
    return chain;
  };

  const makeUpdateChain = () => {
    const result = nextUpdate();
    const chain: any = {};
    chain.set = mock(() => chain);
    chain.where = mock(() => chain);
    chain.returning = mock(async () => result);
    chain.then = (resolve: any, reject: any) =>
      Promise.resolve(result).then(resolve, reject);
    return chain;
  };

  const tx = {
    execute: mock(async () => undefined),
    select: mock(() => makeSelectChain()),
    insert: mock(() => makeInsertChain()),
    update: mock(() => makeUpdateChain()),
  };

  return {
    select: mock(() => makeSelectChain()),
    insert: mock(() => makeInsertChain()),
    update: mock(() => makeUpdateChain()),
    transaction: mock(async (fn: any) => fn(tx)),
  } as unknown as Db;
}

function setup(overrides: {
  progress?: Partial<Progress>;
  selectQueue?: any[][];
  insertQueue?: any[][];
  updateQueue?: any[][];
}) {
  const progress = makeProgress(overrides.progress ?? {});
  const progressService = {
    getWeeklyProgress: mock(async () => progress),
  } as unknown as GoalsProgressService;
  const db = makeDb({
    selectQueue: overrides.selectQueue,
    insertQueue: overrides.insertQueue,
    updateQueue: overrides.updateQueue,
  });
  const service = new GoalPersonalizationService(db, progressService);
  return { service, db, progressService, progress };
}

const oldDate = new Date('2025-01-01T00:00:00Z');
const recentDate = new Date(); // now, so not due

describe('GoalPersonalizationService.stabilization v2', () => {
  it('returns pending_exists when active pending recommendation exists', async () => {
    const pending = { id: 'rec-1', status: 'pending' };
    const { service } = setup({
      selectQueue: [
        [pending], // findPending
      ],
    });

    const result = await service.personalize('user-1');
    expect(result.status).toBe('pending_exists');
    expect((result as any).recommendation.id).toBe('rec-1');
  });

  it('returns not_due when last evaluation is within 7 days', async () => {
    const { service } = setup({
      selectQueue: [
        [], // findPending
        [{ createdAt: recentDate, acceptedAt: null, dismissedAt: null }], // lastRec (goalRecommendations)
      ],
    });

    const result = await service.personalize('user-1');
    expect(result.status).toBe('not_due');
  });

  it('creates insufficient_data marker and does not create pending', async () => {
    const { service } = setup({
      progress: {
        status: 'insufficient_data',
        reason: 'data',
        confidence: 'medium',
        recommendation: {
          action: 'collect_data',
          text: 'Collect more data',
          nothingToChange: true,
          suggestedAdjustment: null,
        },
      },
      selectQueue: [
        [], // findPending
        [], // lastRec (goalRecommendations)
        [], // userProfiles (no goalStartedAt)
        [{ createdAt: oldDate }], // goals (fallback)
      ],
      insertQueue: [[{ id: 'marker-1', status: 'insufficient_data' }]],
    });

    const result = await service.personalize('user-1');
    expect(result.status).toBe('insufficient_data');
  });

  it('creates collect_data marker when confidence is low', async () => {
    const { service } = setup({
      progress: {
        status: 'slightly_off',
        confidence: 'low',
        recommendation: {
          action: 'ease_plan',
          text: 'Ease',
          nothingToChange: false,
          suggestedAdjustment: {
            metrics: { dailyCaloriesGoal: 2300 },
            diff: [{ metric: 'dailyCaloriesGoal', from: 2200, to: 2300 }],
          },
        },
      },
      selectQueue: [
        [], // findPending
        [], // lastRec (goalRecommendations)
        [], // userProfiles (no goalStartedAt)
        [{ createdAt: oldDate }], // goals (fallback)
      ],
      insertQueue: [[{ id: 'marker-2', status: 'collect_data' }]],
    });

    const result = await service.personalize('user-1');
    expect(result.status).toBe('collect_data');
  });

  it('blocks actionable recommendation during cooldown (except slow_down)', async () => {
    const recentAccepted = new Date();
    const { service } = setup({
      progress: {
        status: 'slightly_off',
        reason: 'rate',
        confidence: 'high',
        recommendation: {
          action: 'ease_plan',
          text: 'Ease',
          nothingToChange: false,
          suggestedAdjustment: {
            metrics: { dailyCaloriesGoal: 2300 },
            diff: [{ metric: 'dailyCaloriesGoal', from: 2200, to: 2300 }],
          },
        },
      },
      selectQueue: [
        [], // findPending
        [], // lastRec (goalRecommendations)
        [], // userProfiles (no goalStartedAt)
        [{ createdAt: oldDate }], // goals (fallback)
        [], // recentEvaluations
        [{ acceptedAt: recentAccepted, reasons: [], status: 'accepted' }], // cooldown acceptedRows
      ],
      insertQueue: [[{ id: 'marker-3', status: 'no_change' }]],
    });

    const result = await service.personalize('user-1');
    expect(result.status).toBe('no_change');
  });

  it('allows slow_down even when cooldown is active', async () => {
    const recentAccepted = new Date();
    const { service } = setup({
      progress: {
        status: 'off_track',
        reason: 'rate',
        confidence: 'high',
        metrics: {
          loggedDaysCount: 10,
          weighInsCount: 5,
          activityDaysCount: 8,
          workoutDaysCount: 3,
          sleepNightsCount: 8,
          calorieAdherence: 0.8,
          proteinAdherence: 0.9,
          actualRateKgPerWeek: -1.2,
        },
        recommendation: {
          action: 'slow_down',
          text: 'Slow down',
          nothingToChange: false,
          suggestedAdjustment: {
            metrics: { dailyCaloriesGoal: 2400 },
            diff: [{ metric: 'dailyCaloriesGoal', from: 2200, to: 2400 }],
          },
        },
      },
      selectQueue: [
        [], // findPending
        [], // lastRec (goalRecommendations)
        [], // userProfiles (no goalStartedAt)
        [{ createdAt: oldDate }], // goals (fallback)
        [], // recentEvaluations
        [{ acceptedAt: recentAccepted, reasons: [], status: 'accepted' }], // cooldown acceptedRows
      ],
      insertQueue: [[{ id: 'rec-slow', status: 'pending' }]],
    });

    const result = await service.personalize('user-1');
    expect(result.status).toBe('created');
  });

  it('requires 2-of-3 same signals for slightly_off before creating pending', async () => {
    const { service } = setup({
      progress: {
        status: 'slightly_off',
        reason: 'rate',
        confidence: 'high',
        recommendation: {
          action: 'ease_plan',
          text: 'Ease',
          nothingToChange: false,
          suggestedAdjustment: {
            metrics: { dailyCaloriesGoal: 2300 },
            diff: [{ metric: 'dailyCaloriesGoal', from: 2200, to: 2300 }],
          },
        },
      },
      selectQueue: [
        [], // findPending
        [], // lastRec (goalRecommendations)
        [], // userProfiles (no goalStartedAt)
        [{ createdAt: oldDate }], // goals (fallback)
        [
          // recentEvaluations: no same action+reason
          {
            status: 'no_change',
            reasons: ['status:on_track', 'reason:rate', 'action:none'],
          },
          {
            status: 'no_change',
            reasons: ['status:on_track', 'reason:adherence', 'action:none'],
          },
        ],
        [], // cooldown accepted
      ],
      insertQueue: [[{ id: 'marker-4', status: 'no_change' }]],
    });

    const result = await service.personalize('user-1');
    expect(result.status).toBe('no_change');
  });

  it('creates pending for slightly_off when 2-of-3 same action+reason is met', async () => {
    const { service } = setup({
      progress: {
        status: 'slightly_off',
        reason: 'rate',
        confidence: 'high',
        recommendation: {
          action: 'ease_plan',
          text: 'Ease',
          nothingToChange: false,
          suggestedAdjustment: {
            metrics: { dailyCaloriesGoal: 2300 },
            diff: [{ metric: 'dailyCaloriesGoal', from: 2200, to: 2300 }],
          },
        },
      },
      selectQueue: [
        [], // findPending
        [], // lastRec (goalRecommendations)
        [], // userProfiles (no goalStartedAt)
        [{ createdAt: oldDate }], // goals (fallback)
        [
          {
            status: 'no_change',
            reasons: ['status:slightly_off', 'reason:rate', 'action:ease_plan'],
          },
          {
            status: 'no_change',
            reasons: ['status:on_track', 'reason:rate', 'action:none'],
          },
        ],
        [], // cooldown accepted
      ],
      insertQueue: [[{ id: 'rec-pending', status: 'pending' }]],
    });

    const result = await service.personalize('user-1');
    expect(result.status).toBe('created');
  });

  it('uses collect_data when off_track entry lacks strong evidence', async () => {
    const { service } = setup({
      progress: {
        status: 'off_track',
        reason: 'rate',
        confidence: 'medium',
        metrics: {
          loggedDaysCount: 5,
          weighInsCount: 2,
          activityDaysCount: 3,
          workoutDaysCount: 1,
          sleepNightsCount: 3,
          calorieAdherence: 0.7,
          proteinAdherence: 0.8,
          actualRateKgPerWeek: -0.1,
        },
        recommendation: {
          action: 'adjust_plan',
          text: 'Adjust',
          nothingToChange: false,
          suggestedAdjustment: {
            metrics: { dailyCaloriesGoal: 2100 },
            diff: [{ metric: 'dailyCaloriesGoal', from: 2200, to: 2100 }],
          },
        },
      },
      selectQueue: [
        [], // findPending
        [], // lastRec (goalRecommendations)
        [], // userProfiles (no goalStartedAt)
        [{ createdAt: oldDate }], // goals (fallback)
        [
          {
            status: 'no_change',
            reasons: ['status:on_track', 'reason:rate', 'action:none'],
          },
        ],
        [], // cooldown accepted
      ],
      insertQueue: [[{ id: 'marker-5', status: 'collect_data' }]],
    });

    const result = await service.personalize('user-1');
    expect(result.status).toBe('collect_data');
  });

  it('downgrades adjust_plan to ease/collect_data when adherence is poor', async () => {
    const { service } = setup({
      progress: {
        status: 'off_track',
        reason: 'both',
        confidence: 'high',
        metrics: {
          loggedDaysCount: 10,
          weighInsCount: 5,
          activityDaysCount: 8,
          workoutDaysCount: 3,
          sleepNightsCount: 8,
          calorieAdherence: 0.4,
          proteinAdherence: 0.5,
          actualRateKgPerWeek: -0.1,
        },
        recommendation: {
          action: 'adjust_plan',
          text: 'Adjust',
          nothingToChange: false,
          suggestedAdjustment: {
            metrics: { dailyCaloriesGoal: 2100 },
            diff: [{ metric: 'dailyCaloriesGoal', from: 2200, to: 2100 }],
          },
        },
      },
      selectQueue: [
        [], // findPending
        [], // lastRec (goalRecommendations)
        [], // userProfiles (no goalStartedAt)
        [{ createdAt: oldDate }], // goals (fallback)
        [
          {
            status: 'no_change',
            reasons: ['status:off_track', 'reason:both', 'action:adjust_plan'],
          },
        ],
        [], // cooldown accepted
      ],
      insertQueue: [[{ id: 'rec-eased', status: 'pending' }]],
    });

    const result = await service.personalize('user-1');
    // With poor adherence adjust_plan should not be applied aggressively; it becomes ease_plan
    // and since suggestedAdjustment still exists in this mocked progress, it creates pending.
    expect(result.status).toBe('created');
  });

  it('getPersonalizationState uses goalStartedAt from profile when no recommendations exist', async () => {
    const { service } = setup({
      selectQueue: [
        [], // findPending
        [], // lastRec (goalRecommendations)
        [{ goalStartedAt: recentDate }], // userProfiles
      ],
    });

    const state = await service.getPersonalizationState('user-1');
    expect(state.personalizationDue).toBe(false);
    expect(state.nextAvailableAt).not.toBeNull();
    expect(state.pending).toBeNull();
  });

  it('getPersonalizationState is due when profile goalStartedAt is older than 7 days', async () => {
    const { service } = setup({
      selectQueue: [
        [], // findPending
        [], // lastRec (goalRecommendations)
        [{ goalStartedAt: oldDate }], // userProfiles
      ],
    });

    const state = await service.getPersonalizationState('user-1');
    expect(state.personalizationDue).toBe(true);
    expect(state.nextAvailableAt).toBeNull();
    expect(state.pending).toBeNull();
  });

  it('weight log does not shift nextAvailableAt: profile goalStartedAt wins over recent goals createdAt', async () => {
    // userGoals.version created just now (e.g. after weight log), but plan started long ago.
    const { service } = setup({
      selectQueue: [
        [], // findPending
        [], // lastRec (goalRecommendations)
        [{ goalStartedAt: oldDate }], // userProfiles — userGoals never queried
      ],
    });

    const state = await service.getPersonalizationState('user-1');
    expect(state.personalizationDue).toBe(true);
    expect(state.nextAvailableAt).toBeNull();
  });

  it('getPersonalizationState falls back to goals createdAt when profile has no goalStartedAt', async () => {
    const { service } = setup({
      selectQueue: [
        [], // findPending
        [], // lastRec (goalRecommendations)
        [], // userProfiles (no row / no goalStartedAt)
        [{ createdAt: recentDate }], // goals (fallback)
      ],
    });

    const state = await service.getPersonalizationState('user-1');
    expect(state.personalizationDue).toBe(false);
    expect(state.nextAvailableAt).not.toBeNull();
    expect(state.pending).toBeNull();
  });

  it('acceptRecommendation applies suggestedPlan to profile without restarting cycle', async () => {
    const profile = {
      id: 'prof-1',
      userId: 'user-1',
      weight: 80,
      height: 180,
      age: 30,
      gender: 'male',
      goal: 'lose',
      activityLevel: 'medium',
      weeklyRateKg: 0.5,
      targetWeightKg: 72,
      targetDate: null,
      targetWeightMinKg: null,
      targetWeightMaxKg: null,
      goalStartedAt: new Date('2026-01-01T00:00:00Z'),
    };
    const existingGoals = {
      id: 'goal-1',
      userId: 'user-1',
      dailyCaloriesGoal: 2200,
      startedAt: new Date('2026-01-01T00:00:00Z'),
      endedAt: null,
      mode: 'auto',
      source: 'initial',
    };
    const createdGoals = {
      ...existingGoals,
      id: 'goal-2',
      startedAt: new Date(),
    };

    const { service } = setup({
      updateQueue: [
        [
          {
            id: 'rec-1',
            status: 'accepted',
            acceptedAt: new Date(),
            suggestedPlan: {
              weeklyRateKg: 0.4,
              targetDate: '2026-12-01',
              previousWeeklyRateKg: 0.5,
              previousTargetDate: null,
            },
            recommendedGoals: {
              dailyCaloriesGoal: 2300,
              dailyProteinGoal: 120,
              dailyFatGoal: 60,
              dailyCarbsGoal: 200,
              dailyWaterGoal: 2800,
              dailyStepsGoal: 8000,
              dailyActiveCaloriesGoal: 400,
              weeklyWorkoutsGoal: 3,
              weeklyWorkoutMinutesGoal: 150,
              nightlySleepMinMinutes: 420,
              nightlySleepMaxMinutes: 540,
            },
          },
        ], // claim rec
        [], // update userProfiles
        [], // close existing goals
      ],
      selectQueue: [
        [profile], // userProfiles
        [existingGoals], // userGoals
      ],
      insertQueue: [[createdGoals]], // insert new goals version
    });

    const result = await service.acceptRecommendation('user-1', 'rec-1');

    expect(result.dailyCaloriesGoal).toBe(2300);
  });

  it('acceptRecommendation without suggestedPlan does not touch profile', async () => {
    const profile = {
      id: 'prof-1',
      userId: 'user-1',
      weight: 80,
      height: 180,
      age: 30,
      gender: 'male',
      goal: 'lose',
      activityLevel: 'medium',
      weeklyRateKg: 0.5,
      targetWeightKg: 72,
      targetDate: null,
      targetWeightMinKg: null,
      targetWeightMaxKg: null,
      goalStartedAt: new Date('2026-01-01T00:00:00Z'),
    };
    const existingGoals = {
      id: 'goal-1',
      userId: 'user-1',
      dailyCaloriesGoal: 2200,
      startedAt: new Date('2026-01-01T00:00:00Z'),
      endedAt: null,
    };

    const { service } = setup({
      updateQueue: [
        [
          {
            id: 'rec-1',
            status: 'accepted',
            acceptedAt: new Date(),
            recommendedGoals: {
              dailyCaloriesGoal: 2300,
              dailyProteinGoal: 120,
              dailyFatGoal: 60,
              dailyCarbsGoal: 200,
              dailyWaterGoal: 2800,
              dailyStepsGoal: 8000,
              dailyActiveCaloriesGoal: 400,
              weeklyWorkoutsGoal: 3,
              weeklyWorkoutMinutesGoal: 150,
              nightlySleepMinMinutes: 420,
              nightlySleepMaxMinutes: 540,
            },
          },
        ], // claim rec, no suggestedPlan
        [], // close existing goals
      ],
      selectQueue: [
        [profile], // userProfiles
        [existingGoals], // userGoals
      ],
      insertQueue: [[{ id: 'goal-2' }]],
    });

    const result = await service.acceptRecommendation('user-1', 'rec-1');
    expect(result).toBeDefined();
  });

  it('acceptRecommendation rejects invalid suggestedPlan (targetDate in past)', async () => {
    const profile = {
      id: 'prof-1',
      userId: 'user-1',
      weight: 80,
      height: 180,
      age: 30,
      gender: 'male',
      goal: 'lose',
      activityLevel: 'medium',
      weeklyRateKg: 0.5,
      targetWeightKg: 72,
      targetDate: null,
      targetWeightMinKg: null,
      targetWeightMaxKg: null,
      goalStartedAt: new Date('2026-01-01T00:00:00Z'),
    };

    const { service } = setup({
      updateQueue: [
        [
          {
            id: 'rec-1',
            status: 'accepted',
            acceptedAt: new Date(),
            suggestedPlan: {
              weeklyRateKg: 0.4,
              targetDate: '2020-01-01',
              previousWeeklyRateKg: 0.5,
              previousTargetDate: null,
            },
          },
        ],
      ],
      selectQueue: [[profile]], // userProfiles
    });

    await expect(
      service.acceptRecommendation('user-1', 'rec-1'),
    ).rejects.toThrow();
  });

  it('acceptRecommendation throws when recommendation is not pending', async () => {
    const { service } = setup({
      updateQueue: [[]], // no recRow returned
    });

    await expect(
      service.acceptRecommendation('user-1', 'rec-1'),
    ).rejects.toThrow('Recommendation is not pending');
  });
});
