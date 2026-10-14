import { afterAll, beforeAll, describe, expect, it } from 'bun:test';
import { ConfigModule } from '@nestjs/config';
import { NotFoundException } from '@nestjs/common';
import { and, eq } from 'drizzle-orm';

import { DbModule } from '../../src/db/db.module';
import { dailyActivity } from '../../src/db/schema/dailyActivity';
import { dailySummary } from '../../src/db/schema/dailySummary';
import { goalHistory } from '../../src/db/schema/goalHistory';
import { goalRecommendations } from '../../src/db/schema/goalRecommendations';
import { userGoals } from '../../src/db/schema/userGoals';
import { GoalsModule } from '../../src/goals/goals.module';
import { GoalsService } from '../../src/goals/goals.service';
import { GoalPersonalizationService } from '../../src/goals/personalization/goal-personalization.service';
import type { GoalMetrics } from '../../src/goals/personalization/types';
import type { RecommendationStatus } from '../../src/db/schema/goalRecommendations';
import { createTestModule } from '../utils/app';
import { createTestDb } from '../utils/db';
import type { TestDb, TestTx } from '../utils/db';
import { createProfile, createUser } from '../utils/seed';

let db: TestDb;
let tx: TestTx;
let rollback: () => Promise<void>;
let service: GoalPersonalizationService;
let goalsService: GoalsService;

beforeAll(async () => {
  db = createTestDb();
  const opened = await db.openTx();
  tx = opened.tx;
  rollback = opened.rollback;

  const moduleRef = await createTestModule(
    {
      imports: [
        ConfigModule.forRoot({ isGlobal: true }),
        DbModule,
        GoalsModule,
      ],
    },
    tx,
  );
  service = moduleRef.get(GoalPersonalizationService);
  goalsService = moduleRef.get(GoalsService);
});

afterAll(async () => {
  await rollback();
  await db.close();
});

const DAY_MS = 24 * 60 * 60 * 1000;

const metrics = (overrides: Partial<GoalMetrics> = {}): GoalMetrics => ({
  dailyCaloriesGoal: 2000,
  dailyProteinGoal: 120,
  dailyFatGoal: 60,
  dailyCarbsGoal: 200,
  dailyWaterGoal: 2000,
  dailyStepsGoal: 8000,
  dailyActiveCaloriesGoal: 400,
  weeklyWorkoutsGoal: 3,
  weeklyWorkoutMinutesGoal: 150,
  nightlySleepMinMinutes: 420,
  nightlySleepMaxMinutes: 540,
  ...overrides,
});

const confidence = (overrides = {}) => ({
  level: 'medium' as const,
  dataQualityScore: 0.5,
  trackedDays: 10,
  weightLogsCount: 2,
  activityDays: 5,
  workoutCount: 2,
  sleepNights: 5,
  adherenceStepsPct: null,
  weightTrendKgPerWeek: null,
  ...overrides,
});

async function ageGoals(userId: string, days: number) {
  await tx
    .update(userGoals)
    .set({ createdAt: new Date(Date.now() - days * DAY_MS) })
    .where(eq(userGoals.userId, userId));
}

async function insertRecommendation(
  userId: string,
  overrides: {
    status?: RecommendationStatus;
    previousGoals?: GoalMetrics;
    recommendedGoals?: GoalMetrics;
    expiresAt?: Date;
    acceptedAt?: Date;
    dismissedAt?: Date;
    createdAt?: Date;
  } = {},
) {
  const [rec] = await tx
    .insert(goalRecommendations)
    .values({
      userId,
      status: overrides.status ?? 'pending',
      createdAt: overrides.createdAt,
      previousGoals: overrides.previousGoals ?? metrics(),
      recommendedGoals:
        overrides.recommendedGoals ?? metrics({ dailyCaloriesGoal: 2200 }),
      analysisPeriodStart: '2026-01-01',
      analysisPeriodEnd: '2026-01-14',
      confidence: confidence(),
      expiresAt: overrides.expiresAt ?? new Date(Date.now() + 7 * DAY_MS),
      acceptedAt: overrides.acceptedAt,
      dismissedAt: overrides.dismissedAt,
    })
    .returning();
  return rec!;
}

function dateOffset(days: number): string {
  const d = new Date();
  d.setDate(d.getDate() - days);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(
    d.getDate(),
  ).padStart(2, '0')}`;
}

describe('GoalPersonalizationService.personalize', () => {
  it('reports not_due for a brand new user', async () => {
    const user = await createUser(tx);
    const result = await service.personalize(user.id);
    expect(result.status).toBe('not_due');
  });

  it('reports insufficient_data when there is nothing to analyse', async () => {
    const user = await createUser(tx);
    await createProfile(tx, user.id);
    await goalsService.calculate(user.id);
    await ageGoals(user.id, 20);

    const result = await service.personalize(user.id);
    expect(result.status).toBe('insufficient_data');
  });

  it('returns the existing pending recommendation', async () => {
    const user = await createUser(tx);
    const rec = await insertRecommendation(user.id);

    const result = await service.personalize(user.id);
    expect(result.status).toBe('pending_exists');
    if (result.status === 'pending_exists') {
      expect(result.recommendation).toMatchObject({ id: rec.id });
    }
  });

  it('creates a recommendation when enough data is available', async () => {
    const user = await createUser(tx);
    await createProfile(tx, user.id);
    await goalsService.calculate(user.id);
    await ageGoals(user.id, 20);

    for (let i = 0; i < 3; i++) {
      const date = dateOffset(i);
      await tx.insert(dailyActivity).values({
        userId: user.id,
        date,
        steps: 10000,
        activeCalories: 300,
      });
      await tx.insert(dailySummary).values({
        userId: user.id,
        date,
        totalCalories: 2000,
      });
    }

    const result = await service.personalize(user.id);
    expect(result.status).toBe('created');
  });

  it('expires a stale pending recommendation', async () => {
    const user = await createUser(tx);
    await createProfile(tx, user.id);
    await goalsService.calculate(user.id);
    await ageGoals(user.id, 20);
    const rec = await insertRecommendation(user.id, {
      expiresAt: new Date(Date.now() - DAY_MS),
      createdAt: new Date(Date.now() - 20 * DAY_MS),
    });

    const result = await service.personalize(user.id);
    expect(result.status).toBe('insufficient_data');

    const [row] = await tx
      .select()
      .from(goalRecommendations)
      .where(eq(goalRecommendations.id, rec.id));
    expect(row?.status).toBe('expired');
  });
});

describe('GoalPersonalizationService.getPersonalizationState', () => {
  it('marks personalization as due once the interval elapsed', async () => {
    const user = await createUser(tx);
    await createProfile(tx, user.id);
    await goalsService.calculate(user.id);
    await ageGoals(user.id, 20);

    const state = await service.getPersonalizationState(user.id);
    expect(state.pending).toBeNull();
    expect(state.personalizationDue).toBe(true);
    expect(state.nextAvailableAt).toBeNull();
  });

  it('includes the pending recommendation and blocks a new run', async () => {
    const user = await createUser(tx);
    const rec = await insertRecommendation(user.id);

    const state = await service.getPersonalizationState(user.id);
    expect(state.pending).toMatchObject({ id: rec.id });
    expect(state.personalizationDue).toBe(false);
  });
});

describe('GoalPersonalizationService.acceptRecommendation', () => {
  it('applies the recommended goals and records history', async () => {
    const user = await createUser(tx);
    await createProfile(tx, user.id);
    await goalsService.calculate(user.id);
    const rec = await insertRecommendation(user.id, {
      recommendedGoals: metrics({ dailyCaloriesGoal: 3000 }),
    });

    const result = await service.acceptRecommendation(user.id, rec.id);
    expect(result.dailyCaloriesGoal).toBe(3000);

    const [goals] = await tx
      .select()
      .from(userGoals)
      .where(eq(userGoals.userId, user.id));
    expect(goals?.source).toBe('personalized');
    expect(goals?.dailyCaloriesGoal).toBe(3000);

    const history = await tx
      .select()
      .from(goalHistory)
      .where(
        and(
          eq(goalHistory.userId, user.id),
          eq(goalHistory.reason, 'recommendation_accepted'),
        ),
      );
    expect(history.length).toBeGreaterThan(0);
  });

  it('rejects an already accepted recommendation', async () => {
    const user = await createUser(tx);
    await createProfile(tx, user.id);
    const rec = await insertRecommendation(user.id);
    await service.acceptRecommendation(user.id, rec.id);

    expect(
      service.acceptRecommendation(user.id, rec.id),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it("rejects another user's recommendation", async () => {
    const owner = await createUser(tx);
    const intruder = await createUser(tx);
    const rec = await insertRecommendation(owner.id);

    expect(
      service.acceptRecommendation(intruder.id, rec.id),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});

describe('GoalPersonalizationService.dismissRecommendation', () => {
  it('dismisses a pending recommendation', async () => {
    const user = await createUser(tx);
    const rec = await insertRecommendation(user.id);

    const result = await service.dismissRecommendation(user.id, rec.id);
    expect(result).toEqual({ dismissed: true });

    const [row] = await tx
      .select()
      .from(goalRecommendations)
      .where(eq(goalRecommendations.id, rec.id));
    expect(row?.status).toBe('dismissed');
  });

  it('throws for an unknown recommendation', async () => {
    const user = await createUser(tx);
    expect(
      service.dismissRecommendation(
        user.id,
        '11111111-1111-4111-8111-111111111111',
      ),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});

describe('GoalPersonalizationService.getGoalHistory', () => {
  it('returns recorded goal changes', async () => {
    const user = await createUser(tx);
    await goalsService.update(user.id, { dailyCaloriesGoal: 2100 });

    const history = await service.getGoalHistory(user.id);
    expect(history.length).toBeGreaterThan(0);
    expect(history[0]?.userId).toBe(user.id);
  });
});
