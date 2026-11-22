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

function makeDb(options: { selectQueue?: any[][]; insertQueue?: any[][] }) {
  const selectQueue = [...(options.selectQueue ?? [])];
  const insertQueue = [...(options.insertQueue ?? [])];

  const nextSelect = () => (selectQueue.length ? selectQueue.shift()! : []);
  const nextInsert = () => (insertQueue.length ? insertQueue.shift()! : []);

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
    const chain: any = {};
    chain.set = mock(() => chain);
    chain.where = mock(async () => []);
    chain.returning = mock(async () => []);
    chain.then = (resolve: any, reject: any) =>
      Promise.resolve([]).then(resolve, reject);
    return chain;
  };

  return {
    select: mock(() => makeSelectChain()),
    insert: mock(() => makeInsertChain()),
    update: mock(() => makeUpdateChain()),
    transaction: mock(async (fn: any) => fn({})),
  } as unknown as Db;
}

function setup(overrides: {
  progress?: Partial<Progress>;
  selectQueue?: any[][];
  insertQueue?: any[][];
}) {
  const progress = makeProgress(overrides.progress ?? {});
  const progressService = {
    getWeeklyProgress: mock(async () => progress),
  } as unknown as GoalsProgressService;
  const db = makeDb({
    selectQueue: overrides.selectQueue,
    insertQueue: overrides.insertQueue,
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
        [{ createdAt: oldDate }], // getLastEvaluationAt: userGoals
        [{ createdAt: recentDate, acceptedAt: null, dismissedAt: null }], // lastRec
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
        [{ createdAt: oldDate }], // goals
        [], // lastRec (old/none)
        [], // recentEvaluations
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
        [{ createdAt: oldDate }],
        [],
        [], // recentEvaluations
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
        [{ createdAt: oldDate }],
        [],
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
        [{ createdAt: oldDate }],
        [],
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
        [{ createdAt: oldDate }],
        [],
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
        [], // cooldown recentGoals
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
        [{ createdAt: oldDate }],
        [],
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
        [], // cooldown recentGoals
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
        [{ createdAt: oldDate }],
        [],
        [
          {
            status: 'no_change',
            reasons: ['status:on_track', 'reason:rate', 'action:none'],
          },
        ],
        [], // cooldown accepted
        [], // cooldown recentGoals
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
        [{ createdAt: oldDate }],
        [],
        [
          {
            status: 'no_change',
            reasons: ['status:off_track', 'reason:both', 'action:adjust_plan'],
          },
        ],
        [], // cooldown accepted
        [], // cooldown recentGoals
      ],
      insertQueue: [[{ id: 'rec-eased', status: 'pending' }]],
    });

    const result = await service.personalize('user-1');
    // With poor adherence adjust_plan should not be applied aggressively; it becomes ease_plan
    // and since suggestedAdjustment still exists in this mocked progress, it creates pending.
    expect(result.status).toBe('created');
  });
});
