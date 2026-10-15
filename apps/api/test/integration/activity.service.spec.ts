import {
  afterAll,
  beforeAll,
  describe,
  expect,
  it,
  setSystemTime,
} from 'bun:test';
import { ConfigModule } from '@nestjs/config';
import { eq } from 'drizzle-orm';

import { DbModule } from '../../src/db/db.module';
import { dailyActivity } from '../../src/db/schema/dailyActivity';
import { ActivityModule } from '../../src/activity/activity.module';
import { ActivityService } from '../../src/activity/activity.service';
import { createTestModule } from '../utils/app';
import { createTestDb } from '../utils/db';
import type { TestDb, TestTx } from '../utils/db';
import {
  createDailyActivity,
  createDailySummary,
  createUser,
} from '../utils/seed';

let db: TestDb;
let tx: TestTx;
let rollback: () => Promise<void>;
let service: ActivityService;

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
        ActivityModule,
      ],
    },
    tx,
  );
  service = moduleRef.get(ActivityService);
});

afterAll(async () => {
  await rollback();
  await db.close();
});

describe('ActivityService.sync', () => {
  it('applies defaults for the metrics that are not sent', async () => {
    const user = await createUser(tx);

    const rows = await service.sync(user.id, {
      entries: [{ date: '2026-01-01' }],
    });

    expect(rows).toHaveLength(1);
    expect(rows[0]!.steps).toBe(0);
    expect(rows[0]!.activeCalories).toBe(0);
    expect(rows[0]!.basalCalories).toBe(0);
    expect(rows[0]!.distanceMeters).toBe('0.00');
  });

  it('returns one row per entry', async () => {
    const user = await createUser(tx);

    const rows = await service.sync(user.id, {
      entries: [
        { date: '2026-01-01', steps: 100 },
        { date: '2026-01-02', steps: 200 },
      ],
    });

    expect(rows).toHaveLength(2);
  });

  it('upserts on the (user, date) key', async () => {
    const user = await createUser(tx);

    await service.sync(user.id, {
      entries: [{ date: '2026-01-03', steps: 100 }],
    });
    await service.sync(user.id, {
      entries: [{ date: '2026-01-03', steps: 250 }],
    });

    const rows = await tx
      .select()
      .from(dailyActivity)
      .where(eq(dailyActivity.userId, user.id));

    expect(rows).toHaveLength(1);
    expect(rows[0]!.steps).toBe(250);
  });

  it('persists the provided metrics and rounds the distance', async () => {
    const user = await createUser(tx);

    const rows = await service.sync(user.id, {
      entries: [
        {
          date: '2026-05-01',
          steps: 1234,
          activeCalories: 500,
          basalCalories: 1600,
          distanceMeters: 5_000.5,
        },
      ],
    });

    expect(rows[0]!.steps).toBe(1234);
    expect(rows[0]!.activeCalories).toBe(500);
    expect(rows[0]!.basalCalories).toBe(1600);
    expect(rows[0]!.distanceMeters).toBe('5000.50');
  });

  it('overwrites every metric when the same day is synced again', async () => {
    const user = await createUser(tx);

    await service.sync(user.id, {
      entries: [{ date: '2026-05-02', steps: 1, distanceMeters: 1 }],
    });
    const rows = await service.sync(user.id, {
      entries: [
        {
          date: '2026-05-02',
          steps: 2000,
          activeCalories: 300,
          basalCalories: 1500,
          distanceMeters: 4_000.25,
        },
      ],
    });

    expect(rows[0]!.steps).toBe(2000);
    expect(rows[0]!.activeCalories).toBe(300);
    expect(rows[0]!.basalCalories).toBe(1500);
    expect(rows[0]!.distanceMeters).toBe('4000.25');
  });
});

describe('ActivityService.getToday', () => {
  it('returns the stored day for an explicit date', async () => {
    const user = await createUser(tx);
    await createDailyActivity(tx, user.id, {
      date: '2026-01-04',
      steps: 5_000,
      activeCalories: 300,
    });

    const row = await service.getToday(user.id, '2026-01-04');

    expect(row.steps).toBe(5_000);
    expect(row.activeCalories).toBe(300);
  });

  it('returns an empty stub when the day has no data', async () => {
    const user = await createUser(tx);

    const row = await service.getToday(user.id, '2026-01-05');

    expect(row.id).toBeNull();
    expect(row.steps).toBe(0);
    expect(row.activeCalories).toBe(0);
    expect(row.distanceMeters).toBe('0');
  });

  it('defaults the date to the user time zone when omitted', async () => {
    const user = await createUser(tx, { timeZone: 'Pacific/Kiritimati' });
    await createDailyActivity(tx, user.id, { date: '2026-01-02', steps: 1234 });

    setSystemTime(new Date('2026-01-01T23:30:00Z'));
    let row;
    try {
      row = await service.getToday(user.id);
    } finally {
      setSystemTime();
    }

    expect(row.steps).toBe(1234);
  });

  it('falls back to UTC when the user has no profile', async () => {
    const user = await createUser(tx);
    await createDailyActivity(tx, user.id, { date: '2026-01-01', steps: 777 });

    setSystemTime(new Date('2026-01-01T23:30:00Z'));
    let row;
    try {
      row = await service.getToday(user.id);
    } finally {
      setSystemTime();
    }

    expect(row.steps).toBe(777);
  });
});

describe('ActivityService.getRange', () => {
  it('merges the daily summary into consumed and net calories', async () => {
    const user = await createUser(tx);
    await createDailyActivity(tx, user.id, {
      date: '2026-01-01',
      steps: 100,
      activeCalories: 400,
      basalCalories: 1_600,
      distanceMeters: '5000.5',
    });
    await createDailySummary(tx, user.id, {
      date: '2026-01-01',
      totalCalories: 2_100,
    });

    const rows = await service.getRange(user.id, '2026-01-01', '2026-01-31');

    expect(rows).toEqual([
      {
        date: '2026-01-01',
        steps: 100,
        activeCalories: 400,
        basalCalories: 1_600,
        distanceMeters: 5_000.5,
        caloriesConsumed: 2_100,
        netCalories: 1_700,
      },
    ]);
  });

  it('treats a missing summary as zero consumed calories', async () => {
    const user = await createUser(tx);
    await createDailyActivity(tx, user.id, {
      date: '2026-01-02',
      activeCalories: 250,
    });

    const rows = await service.getRange(user.id, '2026-01-01', '2026-01-31');

    expect(rows[0]!.caloriesConsumed).toBe(0);
    expect(rows[0]!.netCalories).toBe(-250);
  });

  it('orders the days ascending and skips rows outside the range', async () => {
    const user = await createUser(tx);
    await createDailyActivity(tx, user.id, { date: '2026-02-02' });
    await createDailyActivity(tx, user.id, { date: '2026-02-01' });
    await createDailyActivity(tx, user.id, { date: '2026-03-01' });

    const rows = await service.getRange(user.id, '2026-02-01', '2026-02-28');

    expect(rows.map((row) => row.date)).toEqual(['2026-02-01', '2026-02-02']);
  });

  it('returns nothing for a range without activity', async () => {
    const user = await createUser(tx);

    const rows = await service.getRange(user.id, '2026-06-01', '2026-06-30');

    expect(rows).toEqual([]);
  });

  it('ignores a summary that has no matching activity day', async () => {
    const user = await createUser(tx);
    await createDailySummary(tx, user.id, {
      date: '2026-06-01',
      totalCalories: 2_000,
    });

    const rows = await service.getRange(user.id, '2026-06-01', '2026-06-30');

    expect(rows).toEqual([]);
  });

  it('only returns the rows of the given user', async () => {
    const user = await createUser(tx);
    const other = await createUser(tx);
    await createDailyActivity(tx, user.id, { date: '2026-04-01', steps: 10 });
    await createDailyActivity(tx, other.id, { date: '2026-04-01', steps: 999 });

    const rows = await service.getRange(user.id, '2026-04-01', '2026-04-30');

    expect(rows).toHaveLength(1);
    expect(rows[0]!.steps).toBe(10);
  });
});
