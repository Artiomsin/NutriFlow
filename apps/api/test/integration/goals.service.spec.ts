import { afterAll, beforeAll, describe, expect, it } from 'bun:test';
import { randomUUID } from 'node:crypto';
import { ConfigModule } from '@nestjs/config';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { and, eq } from 'drizzle-orm';

import { createDb } from '../../src/db/db';
import { DbModule } from '../../src/db/db.module';
import { goalHistory } from '../../src/db/schema/goalHistory';
import { goalRecommendations } from '../../src/db/schema/goalRecommendations';
import { userGoals } from '../../src/db/schema/userGoals';
import { userProfiles } from '../../src/db/schema/userProfiles';
import { users } from '../../src/db/schema/users';
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

  it('serializes simultaneous edits so they create one history entry', async () => {
    const concurrentDb = createDb(db.pool);
    const concurrentService = new GoalsService(concurrentDb);
    const [user] = await concurrentDb
      .insert(users)
      .values({ email: `concurrent-goals-${randomUUID()}@test.com` })
      .returning();

    try {
      await Promise.all([
        concurrentService.update(user!.id, { dailyCaloriesGoal: 2100 }),
        concurrentService.update(user!.id, { dailyCaloriesGoal: 2200 }),
      ]);

      const history = await concurrentDb
        .select()
        .from(goalHistory)
        .where(
          and(
            eq(goalHistory.userId, user!.id),
            eq(goalHistory.metric, 'dailyCaloriesGoal'),
            eq(goalHistory.reason, 'user_edit'),
          ),
        );

      expect(history).toHaveLength(1);
      expect(history[0]?.oldValue).toBeNull();
      expect([2100, 2200].includes(history[0]?.newValue ?? -1)).toBe(true);
    } finally {
      await concurrentDb.delete(users).where(eq(users.id, user!.id));
    }
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

describe('GoalsService.findByUserId by date', () => {
  async function seedVersions(userId: string) {
    const first = await service.update(userId, {
      dailyCaloriesGoal: 2000,
      dailyStepsGoal: 6000,
    });
    const second = await service.update(userId, { dailyCaloriesGoal: 2500 });

    await tx
      .update(userGoals)
      .set({
        startedAt: new Date('2026-01-01T00:00:00.000Z'),
        endedAt: new Date('2026-01-11T00:00:00.000Z'),
      })
      .where(eq(userGoals.id, first!.id));

    await tx
      .update(userGoals)
      .set({ startedAt: new Date('2026-01-11T00:00:00.000Z') })
      .where(eq(userGoals.id, second!.id));

    return { first, second };
  }

  it('returns the version that was active on that day', async () => {
    const user = await createUser(tx);
    await seedVersions(user.id);

    const firstDay = await service.findByUserId(user.id, '2026-01-01');
    expect(firstDay.dailyCaloriesGoal).toBe(2000);

    const beforeChange = await service.findByUserId(user.id, '2026-01-10');
    expect(beforeChange.dailyCaloriesGoal).toBe(2000);
    expect(beforeChange.dailyStepsGoal).toBe(6000);

    const changeDay = await service.findByUserId(user.id, '2026-01-11');
    expect(changeDay.dailyCaloriesGoal).toBe(2500);
    // update() merges partial changes instead of wiping other metrics
    expect(changeDay.dailyStepsGoal).toBe(6000);

    const later = await service.findByUserId(user.id, '2026-02-01');
    expect(later.dailyCaloriesGoal).toBe(2500);
  });

  it('throws when no goal version existed on that day', async () => {
    const user = await createUser(tx);
    await seedVersions(user.id);

    expect(service.findByUserId(user.id, '2025-12-31')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('returns the active version when no date is given', async () => {
    const user = await createUser(tx);
    await seedVersions(user.id);

    const current = await service.findByUserId(user.id);
    expect(current.dailyCaloriesGoal).toBe(2500);
    expect(current.endedAt).toBeNull();
  });

  it('resolves day boundaries in the requested time zone', async () => {
    const user = await createUser(tx);
    const first = await service.update(user.id, { dailyCaloriesGoal: 2000 });
    const second = await service.update(user.id, { dailyCaloriesGoal: 2500 });

    // Goal changed at 01:00 on Jan 12 in Moscow (UTC+3) == Jan 11 22:00 UTC.
    await tx
      .update(userGoals)
      .set({
        startedAt: new Date('2026-01-01T00:00:00.000Z'),
        endedAt: new Date('2026-01-11T22:00:00.000Z'),
      })
      .where(eq(userGoals.id, first!.id));

    await tx
      .update(userGoals)
      .set({ startedAt: new Date('2026-01-11T22:00:00.000Z') })
      .where(eq(userGoals.id, second!.id));

    // UTC sees the change on Jan 11, so the new version is selected.
    const utcDay = await service.findByUserId(user.id, '2026-01-11', 'UTC');
    expect(utcDay.dailyCaloriesGoal).toBe(2500);

    // Moscow still treats it as Jan 11, so the old version is selected.
    const moscowDay = await service.findByUserId(
      user.id,
      '2026-01-11',
      'Europe/Moscow',
    );
    expect(moscowDay.dailyCaloriesGoal).toBe(2000);

    const moscowNextDay = await service.findByUserId(
      user.id,
      '2026-01-12',
      'Europe/Moscow',
    );
    expect(moscowNextDay.dailyCaloriesGoal).toBe(2500);
  });
});

describe('GoalsService.getHistory', () => {
  it('returns one entry per version with the diff against the previous one', async () => {
    const user = await createUser(tx);
    await service.update(user.id, {
      dailyCaloriesGoal: 2100,
      dailyProteinGoal: 150,
    });
    await service.update(user.id, { dailyCaloriesGoal: 2200 });

    const page = await service.getHistory(user.id, { limit: 20 });

    expect(page.items).toHaveLength(2);
    expect(page.nextCursor).toBeNull();

    const [latest, first] = page.items;
    expect(latest?.reason).toBe('user_edit');
    expect(latest?.changes).toEqual([
      { metric: 'dailyCaloriesGoal', from: 2100, to: 2200 },
    ]);
    expect(first?.changes).toEqual(
      expect.arrayContaining([
        { metric: 'dailyCaloriesGoal', from: null, to: 2100 },
        { metric: 'dailyProteinGoal', from: null, to: 150 },
      ]),
    );
  });

  it('keeps frequent edits as separate entries instead of coalescing', async () => {
    const user = await createUser(tx);
    await service.update(user.id, { dailyCaloriesGoal: 2100 });
    await service.update(user.id, { dailyCaloriesGoal: 2200 });
    await service.update(user.id, { dailyCaloriesGoal: 2300 });

    const page = await service.getHistory(user.id, { limit: 20 });

    expect(page.items).toHaveLength(3);
    expect(page.items[0]?.changes).toEqual([
      { metric: 'dailyCaloriesGoal', from: 2200, to: 2300 },
    ]);
    expect(page.items[1]?.changes).toEqual([
      { metric: 'dailyCaloriesGoal', from: 2100, to: 2200 },
    ]);
  });

  it('paginates without skipping or repeating versions', async () => {
    const user = await createUser(tx);

    for (const calories of [2100, 2200, 2300]) {
      await service.update(user.id, { dailyCaloriesGoal: calories });
    }

    const firstPage = await service.getHistory(user.id, { limit: 2 });

    expect(firstPage.items.map((item) => item.goal.dailyCaloriesGoal)).toEqual([
      2300, 2200,
    ]);
    // The oldest visible entry still has its diff, computed from the extra
    // predecessor row fetched beyond the page.
    expect(firstPage.items[1]?.changes).toEqual([
      { metric: 'dailyCaloriesGoal', from: 2100, to: 2200 },
    ]);
    expect(firstPage.nextCursor).toBe(firstPage.items[1]?.id ?? null);

    const secondPage = await service.getHistory(user.id, {
      limit: 2,
      cursor: firstPage.nextCursor!,
    });

    expect(secondPage.items.map((item) => item.goal.dailyCaloriesGoal)).toEqual(
      [2100],
    );
    expect(secondPage.items[0]?.changes).toEqual([
      { metric: 'dailyCaloriesGoal', from: null, to: 2100 },
    ]);
    expect(secondPage.nextCursor).toBeNull();
  });

  it('rejects an unknown cursor', async () => {
    const user = await createUser(tx);

    await expect(
      service.getHistory(user.id, {
        limit: 20,
        cursor: '11111111-1111-4111-8111-111111111111',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('resolves the versions in effect during a day in the profile time zone', async () => {
    const user = await createUser(tx);

    await tx.insert(userGoals).values([
      {
        userId: user.id,
        dailyCaloriesGoal: 2000,
        source: 'user',
        changeReason: 'user_edit',
        startedAt: new Date('2026-11-09T00:00:00Z'),
        endedAt: new Date('2026-11-10T16:00:00Z'),
      },
      {
        userId: user.id,
        dailyCaloriesGoal: 2400,
        source: 'user',
        changeReason: 'user_edit',
        startedAt: new Date('2026-11-10T16:00:00Z'),
        endedAt: null,
      },
    ]);

    const utc = await service.getHistory(user.id, {
      date: '2026-11-10',
      tz: 'UTC',
      limit: 20,
    });
    expect(utc.items.map((item) => item.goal.dailyCaloriesGoal)).toEqual([
      2400, 2000,
    ]);

    // Tokyo's November 10th ends at 15:00 UTC, before the new version starts.
    const tokyo = await service.getHistory(user.id, {
      date: '2026-11-10',
      tz: 'Asia/Tokyo',
      limit: 20,
    });
    expect(tokyo.items.map((item) => item.goal.dailyCaloriesGoal)).toEqual([
      2000,
    ]);
  });
});
