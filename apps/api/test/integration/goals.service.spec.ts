import { afterAll, beforeAll, describe, expect, it } from 'bun:test';
import { ConfigModule } from '@nestjs/config';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { and, eq } from 'drizzle-orm';

import { DbModule } from '../../src/db/db.module';
import { goalHistory } from '../../src/db/schema/goalHistory';
import { goalRecommendations } from '../../src/db/schema/goalRecommendations';
import { userGoals } from '../../src/db/schema/userGoals';
import { userProfiles } from '../../src/db/schema/userProfiles';
import { GoalsModule } from '../../src/goals/goals.module';
import { GoalsService } from '../../src/goals/goals.service';
import type { GoalMetrics } from '../../src/goals/personalization/types';
import { createTestModule } from '../utils/app';
import { createTestDb } from '../utils/db';
import type { TestDb, TestTx } from '../utils/db';
import { createProfile, createUser } from '../utils/seed';

let db: TestDb;
let tx: TestTx;
let rollback: () => Promise<void>;
let service: GoalsService;

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
  service = moduleRef.get(GoalsService);
});

afterAll(async () => {
  await rollback();
  await db.close();
});

async function loadHistory(userId: string, reason: string) {
  return tx
    .select()
    .from(goalHistory)
    .where(and(eq(goalHistory.userId, userId), eq(goalHistory.reason, reason)));
}

describe('GoalsService.findByUserId', () => {
  it('throws when the user has no goals', async () => {
    const user = await createUser(tx);
    expect(service.findByUserId(user.id)).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('returns the stored goals', async () => {
    const user = await createUser(tx);
    await service.update(user.id, { dailyCaloriesGoal: 2000 });

    const goals = await service.findByUserId(user.id);
    expect(goals.dailyCaloriesGoal).toBe(2000);
  });
});

describe('GoalsService.update', () => {
  it('creates user goals and records history when none exist', async () => {
    const user = await createUser(tx);
    const goals = (await service.update(user.id, {
      dailyCaloriesGoal: 2100,
      dailyStepsGoal: 7000,
    }))!;

    expect(goals.source).toBe('user');
    expect(goals.dailyCaloriesGoal).toBe(2100);

    const history = await loadHistory(user.id, 'user_edit');
    expect(history.length).toBeGreaterThan(0);
    expect(history.every((h) => h.source === 'user')).toBe(true);
  });

  it('coalesces consecutive edits to the same goal into one history entry', async () => {
    const user = await createUser(tx);
    await service.update(user.id, { dailyCaloriesGoal: 2000 });

    const [firstEntry] = await loadHistory(user.id, 'user_edit');
    const sessionStart = new Date(Date.now() - 5 * 60 * 1000);
    await tx
      .update(goalHistory)
      .set({ createdAt: sessionStart, updatedAt: sessionStart })
      .where(eq(goalHistory.id, firstEntry!.id));

    const updated = (await service.update(user.id, {
      dailyCaloriesGoal: 2400,
    }))!;

    expect(updated.dailyCaloriesGoal).toBe(2400);

    const history = await loadHistory(user.id, 'user_edit');
    const calories = history.filter((h) => h.metric === 'dailyCaloriesGoal');
    expect(calories).toHaveLength(1);
    expect(calories[0]?.id).toBe(firstEntry?.id);
    expect(calories[0]?.oldValue).toBeNull();
    expect(calories[0]?.newValue).toBe(2400);
    expect(calories[0]?.createdAt.getTime()).toBe(sessionStart.getTime());
    expect(calories[0]?.updatedAt.getTime()).toBeGreaterThan(
      sessionStart.getTime(),
    );
  });
});

describe('GoalsService.calculate', () => {
  it('throws when the profile is missing', async () => {
    const user = await createUser(tx);
    expect(service.calculate(user.id)).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('throws when the profile is incomplete', async () => {
    const user = await createUser(tx);
    await createProfile(tx, user.id, { activityLevel: null });

    expect(service.calculate(user.id)).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });

  it('creates initial goals from a complete profile', async () => {
    const user = await createUser(tx);
    await createProfile(tx, user.id, {
      weight: 80,
      height: 180,
      age: 30,
      gender: 'male',
      goal: 'maintain',
      activityLevel: 'medium',
    });

    const goals = (await service.calculate(user.id))!;
    expect(goals.source).toBe('initial');
    expect(goals.dailyCaloriesGoal).toBe(2759);
    expect(goals.dailyProteinGoal).toBe(128);
    expect(goals.dailyWaterGoal).toBe(2800);
    expect(goals.dailyStepsGoal).toBe(8000);
    expect(goals.nightlySleepMinMinutes).toBe(420);

    const history = await loadHistory(user.id, 'initial_calculation');
    expect(history.length).toBeGreaterThan(0);
  });

  it('preserves manually-set goals on profile recalculation', async () => {
    const user = await createUser(tx);
    await createProfile(tx, user.id);
    await service.update(user.id, { dailyCaloriesGoal: 3000 });

    await tx
      .update(userProfiles)
      .set({ weight: 95, updatedAt: new Date() })
      .where(eq(userProfiles.userId, user.id));

    const goals = (await service.calculate(user.id))!;
    expect(goals.dailyCaloriesGoal).toBe(3000);
    expect(goals.source).toBe('user');
  });
});

describe('GoalsService.resetToAutomatic', () => {
  it('overwrites a manual source with freshly calculated goals', async () => {
    const user = await createUser(tx);
    await createProfile(tx, user.id);
    await service.update(user.id, { dailyCaloriesGoal: 3000 });

    const goals = (await service.resetToAutomatic(user.id))!;
    expect(goals.source).toBe('initial');
    expect(goals.dailyCaloriesGoal).toBe(2759);

    const history = await loadHistory(user.id, 'manual_reset_to_automatic');
    expect(history.length).toBeGreaterThan(0);
  });
});

describe('GoalsService personalized recalculation', () => {
  it('applies the accepted recommendation delta on the next calculation', async () => {
    const user = await createUser(tx);
    await createProfile(tx, user.id);
    await service.calculate(user.id);

    await tx
      .update(userGoals)
      .set({ source: 'personalized' })
      .where(eq(userGoals.userId, user.id));

    const previousGoals = {
      dailyCaloriesGoal: 2000,
      dailyProteinGoal: null,
      dailyFatGoal: null,
      dailyCarbsGoal: null,
      dailyWaterGoal: null,
      dailyStepsGoal: null,
      dailyActiveCaloriesGoal: null,
      weeklyWorkoutsGoal: null,
      weeklyWorkoutMinutesGoal: null,
      nightlySleepMinMinutes: null,
      nightlySleepMaxMinutes: null,
    } as GoalMetrics;
    const recommendedGoals = {
      ...previousGoals,
      dailyCaloriesGoal: 2200,
    } as GoalMetrics;

    await tx.insert(goalRecommendations).values({
      userId: user.id,
      status: 'accepted',
      acceptedAt: new Date(),
      previousGoals,
      recommendedGoals,
      analysisPeriodStart: '2026-01-01',
      analysisPeriodEnd: '2026-01-14',
      confidence: {
        level: 'medium',
        dataQualityScore: 0.5,
        trackedDays: 10,
        weightLogsCount: 2,
        activityDays: 5,
        workoutCount: 2,
        sleepNights: 5,
        adherenceStepsPct: null,
        weightTrendKgPerWeek: null,
      },
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
    });

    const goals = (await service.calculate(user.id))!;
    expect(goals.source).toBe('personalized');
    expect(goals.dailyCaloriesGoal).toBe(2959);
  });
});
