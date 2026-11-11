import { afterAll, beforeAll, describe, expect, it } from 'bun:test';
import { ConfigModule } from '@nestjs/config';

import { AnalyticsService } from '../../src/analytics/analytics.service';
import { AnalyticsModule } from '../../src/analytics/analytics.module';
import { DbModule } from '../../src/db/db.module';
import { userGoals } from '../../src/db/schema/userGoals';
import { createTestModule } from '../utils/app';
import { createTestDb } from '../utils/db';
import type { TestDb, TestTx } from '../utils/db';
import { createDailySummary, createProfile, createUser } from '../utils/seed';

let db: TestDb;
let tx: TestTx;
let rollback: () => Promise<void>;
let service: AnalyticsService;

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
        AnalyticsModule,
      ],
    },
    tx,
  );
  service = moduleRef.get(AnalyticsService);
});

afterAll(async () => {
  await rollback();
  await db.close();
});

async function seedVersions(
  userId: string,
  changeAt: Date,
  oldCalories = 2000,
  newCalories = 3000,
) {
  await tx.insert(userGoals).values({
    userId,
    dailyCaloriesGoal: oldCalories,
    source: 'initial',
    startedAt: new Date('2026-01-01T00:00:00.000Z'),
    endedAt: changeAt,
    createdAt: new Date('2026-01-01T00:00:00.000Z'),
    updatedAt: changeAt,
  });

  await tx.insert(userGoals).values({
    userId,
    dailyCaloriesGoal: newCalories,
    source: 'user',
    startedAt: changeAt,
    endedAt: null,
    createdAt: changeAt,
    updatedAt: changeAt,
  });
}

describe('AnalyticsService.getCustomRange', () => {
  it('compares a past range with the goal active at its end', async () => {
    const user = await createUser(tx);
    await createProfile(tx, user.id);
    await seedVersions(user.id, new Date('2026-01-11T00:00:00.000Z'));

    for (let day = 1; day <= 14; day++) {
      await createDailySummary(tx, user.id, {
        date: `2026-01-${String(day).padStart(2, '0')}`,
        totalCalories: 2000,
      });
    }

    const beforeChange = await service.getCustomRange(
      user.id,
      '2026-01-01',
      '2026-01-07',
      'UTC',
    );
    expect(beforeChange.goalCalories).toBe(2000);
    expect(beforeChange.goalCaloriesPct).toBe(100);

    const afterChange = await service.getCustomRange(
      user.id,
      '2026-01-08',
      '2026-01-14',
      'UTC',
    );
    expect(afterChange.goalCalories).toBe(3000);
    expect(afterChange.goalCaloriesPct).toBe(67);
  });

  it('resolves the range end in the requested time zone', async () => {
    const user = await createUser(tx);
    await createProfile(tx, user.id);
    // Goal changed at 01:00 on Jan 12 in Moscow == Jan 11 22:00 UTC.
    await seedVersions(user.id, new Date('2026-01-11T22:00:00.000Z'));

    const utc = await service.getCustomRange(
      user.id,
      '2026-01-05',
      '2026-01-11',
      'UTC',
    );
    expect(utc.goalCalories).toBe(3000);

    const moscow = await service.getCustomRange(
      user.id,
      '2026-01-05',
      '2026-01-11',
      'Europe/Moscow',
    );
    expect(moscow.goalCalories).toBe(2000);
  });
});
