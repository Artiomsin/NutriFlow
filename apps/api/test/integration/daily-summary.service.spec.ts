import {
  afterAll,
  beforeAll,
  describe,
  expect,
  it,
  setSystemTime,
} from 'bun:test';
import { ConfigModule } from '@nestjs/config';
import { and, eq, sql } from 'drizzle-orm';

import { DbModule } from '../../src/db/db.module';
import { dailySummary } from '../../src/db/schema/dailySummary';
import { foodEntries } from '../../src/db/schema/foodEntries';
import { waterEntries } from '../../src/db/schema/waterEntries';
import { DailySummaryModule } from '../../src/daily-summary/daily-summary.module';
import { DailySummaryService } from '../../src/daily-summary/daily-summary.service';
import { createTestModule } from '../utils/app';
import { createTestDb } from '../utils/db';
import type { TestDb, TestTx } from '../utils/db';
import { createUser } from '../utils/seed';

let db: TestDb;
let tx: TestTx;
let rollback: () => Promise<void>;
let service: DailySummaryService;

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
        DailySummaryModule,
      ],
    },
    tx,
  );
  service = moduleRef.get(DailySummaryService);
});

afterAll(async () => {
  await rollback();
  await db.close();
});

const dateWhere = (userId: string, date: string) =>
  and(
    eq(dailySummary.userId, userId),
    sql`${dailySummary.date} = ${date}::date`,
  );

async function loadSummary(userId: string, date: string) {
  const [row] = await tx
    .select()
    .from(dailySummary)
    .where(dateWhere(userId, date));
  return row;
}

describe('DailySummaryService.adjust', () => {
  it('ignores a delta of all zeroes', async () => {
    const user = await createUser(tx);
    await service.adjust(user.id, { date: '2026-03-01' });
    expect(await loadSummary(user.id, '2026-03-01')).toBeUndefined();
  });

  it('creates a row for the first positive delta', async () => {
    const user = await createUser(tx);
    await service.adjust(user.id, {
      calories: 500,
      protein: 30,
      fat: 10,
      carbs: 60,
      waterMl: 250,
      date: '2026-03-02',
    });

    const row = await loadSummary(user.id, '2026-03-02');
    expect(row?.totalCalories).toBe(500);
    expect(row?.totalProtein).toBe(30);
    expect(row?.totalFat).toBe(10);
    expect(row?.totalCarbs).toBe(60);
    expect(row?.totalWaterMl).toBe(250);
  });

  it('accumulates successive deltas', async () => {
    const user = await createUser(tx);
    await service.adjust(user.id, { calories: 200, date: '2026-03-03' });
    await service.adjust(user.id, { calories: 300, date: '2026-03-03' });

    const row = await loadSummary(user.id, '2026-03-03');
    expect(row?.totalCalories).toBe(500);
  });

  it('applies only the provided fields', async () => {
    const user = await createUser(tx);
    await service.adjust(user.id, { waterMl: 300, date: '2026-03-04' });

    const row = await loadSummary(user.id, '2026-03-04');
    expect(row?.totalWaterMl).toBe(300);
    expect(row?.totalCalories).toBe(0);
  });

  it('does not create a row for a negative delta with no prior row', async () => {
    const user = await createUser(tx);
    await service.adjust(user.id, { calories: -100, date: '2026-03-05' });
    expect(await loadSummary(user.id, '2026-03-05')).toBeUndefined();
  });

  it('clamps totals at zero', async () => {
    const user = await createUser(tx);
    await service.adjust(user.id, { calories: 100, date: '2026-03-06' });
    await service.adjust(user.id, { calories: -500, date: '2026-03-06' });

    const row = await loadSummary(user.id, '2026-03-06');
    expect(row?.totalCalories).toBe(0);
  });

  it("defaults the date to the user's timezone", async () => {
    const user = await createUser(tx, { timeZone: 'Pacific/Kiritimati' });
    setSystemTime(new Date('2026-01-01T23:30:00Z'));
    try {
      await service.adjust(user.id, { calories: 10 });
    } finally {
      setSystemTime();
    }

    expect(await loadSummary(user.id, '2026-01-02')).toBeDefined();
  });
});

describe('DailySummaryService.findToday', () => {
  it('returns an empty summary when no row exists', async () => {
    const user = await createUser(tx);
    const summary = await service.findToday(user.id, '2026-04-01');
    expect(summary.id).toBeNull();
    expect(summary.totalCalories).toBe(0);
    expect(summary.totalWaterMl).toBe(0);
  });

  it('returns the stored summary for a date', async () => {
    const user = await createUser(tx);
    await service.adjust(user.id, { calories: 400, date: '2026-04-02' });

    const summary = await service.findToday(user.id, '2026-04-02');
    expect(summary.totalCalories).toBe(400);
  });
});

describe('DailySummaryService.findByDate', () => {
  it('returns an empty summary for a missing date', async () => {
    const user = await createUser(tx);
    const summary = await service.findByDate(user.id, '2026-05-01');
    expect(summary.id).toBeNull();
  });

  it('returns the stored summary for a date', async () => {
    const user = await createUser(tx);
    await service.adjust(user.id, { waterMl: 750, date: '2026-05-02' });

    const summary = await service.findByDate(user.id, '2026-05-02');
    expect(summary.totalWaterMl).toBe(750);
  });
});

describe('DailySummaryService.findRange', () => {
  it('returns only rows inside the range, ordered by date', async () => {
    const user = await createUser(tx);
    await service.adjust(user.id, { calories: 100, date: '2026-06-05' });
    await service.adjust(user.id, { calories: 200, date: '2026-06-01' });
    await service.adjust(user.id, { calories: 999, date: '2026-06-20' });

    const rows = await service.findRange(user.id, '2026-06-01', '2026-06-10');
    expect(rows.map((r) => r.totalCalories)).toEqual([200, 100]);
  });

  it('returns an empty array when nothing matches', async () => {
    const user = await createUser(tx);
    const rows = await service.findRange(user.id, '2026-07-01', '2026-07-10');
    expect(rows).toEqual([]);
  });
});

describe('DailySummaryService.findTodayDashboard', () => {
  it('returns an empty summary and empty lists', async () => {
    const user = await createUser(tx);
    const dashboard = await service.findTodayDashboard(user.id, '2026-08-01');
    expect(dashboard.dailySummary.id).toBeNull();
    expect(dashboard.foodEntries).toEqual([]);
    expect(dashboard.waterEntries).toEqual([]);
  });

  it('returns the summary, food entries and water entries', async () => {
    const user = await createUser(tx);
    await service.adjust(user.id, { calories: 250, date: '2026-08-02' });
    await tx.insert(foodEntries).values({
      userId: user.id,
      name: 'Yogurt',
      calories: 250,
      entryDate: '2026-08-02',
    });
    await tx.insert(waterEntries).values({
      userId: user.id,
      amountMl: 500,
      entryDate: '2026-08-02',
    });

    const dashboard = await service.findTodayDashboard(user.id, '2026-08-02');
    expect(dashboard.dailySummary.totalCalories).toBe(250);
    expect(dashboard.foodEntries).toHaveLength(1);
    expect(dashboard.foodEntries[0]?.name).toBe('Yogurt');
    expect(dashboard.waterEntries).toHaveLength(1);
    expect(dashboard.waterEntries[0]?.amountMl).toBe(500);
  });
});
