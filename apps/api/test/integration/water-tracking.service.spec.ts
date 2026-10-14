import {
  afterAll,
  beforeAll,
  describe,
  expect,
  it,
  setSystemTime,
} from 'bun:test';
import { ConfigModule } from '@nestjs/config';
import { NotFoundException } from '@nestjs/common';
import { and, eq, sql } from 'drizzle-orm';
import { randomUUID } from 'node:crypto';

import { DbModule } from '../../src/db/db.module';
import { dailySummary } from '../../src/db/schema/dailySummary';
import { WaterTrackingModule } from '../../src/water-tracking/water-tracking.module';
import { WaterTrackingService } from '../../src/water-tracking/water-tracking.service';
import { createTestModule } from '../utils/app';
import { createTestDb } from '../utils/db';
import type { TestDb, TestTx } from '../utils/db';
import { createUser } from '../utils/seed';

let db: TestDb;
let tx: TestTx;
let rollback: () => Promise<void>;
let service: WaterTrackingService;

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
        WaterTrackingModule,
      ],
    },
    tx,
  );
  service = moduleRef.get(WaterTrackingService);
});

afterAll(async () => {
  await rollback();
  await db.close();
});

async function loadSummary(userId: string, date: string) {
  const [row] = await tx
    .select()
    .from(dailySummary)
    .where(
      and(
        eq(dailySummary.userId, userId),
        sql`${dailySummary.date} = ${date}::date`,
      ),
    );
  return row;
}

describe('WaterTrackingService.create', () => {
  it('inserts an entry and increments the daily summary', async () => {
    const user = await createUser(tx);
    const entry = await service.create(user.id, {
      amountMl: 500,
      date: '2026-01-01',
    });

    expect(entry!.amountMl).toBe(500);

    const summary = await loadSummary(user.id, '2026-01-01');
    expect(summary?.totalWaterMl).toBe(500);
  });

  it("defaults the date to the user's timezone", async () => {
    const user = await createUser(tx, { timeZone: 'Pacific/Kiritimati' });
    setSystemTime(new Date('2026-01-01T23:30:00Z'));
    let entry;
    try {
      entry = await service.create(user.id, { amountMl: 250 });
    } finally {
      setSystemTime();
    }

    expect(entry!.entryDate).toBe('2026-01-02');
  });
});

describe('WaterTrackingService reads', () => {
  it('returns entries for a given date via getByDate', async () => {
    const user = await createUser(tx);
    await service.create(user.id, { amountMl: 300, date: '2026-01-05' });
    await service.create(user.id, { amountMl: 200, date: '2026-01-06' });

    const rows = await service.getByDate(user.id, '2026-01-05');
    expect(rows).toHaveLength(1);
    expect(rows[0]?.amountMl).toBe(300);
  });

  it('returns entries for a given date via getToday', async () => {
    const user = await createUser(tx);
    await service.create(user.id, { amountMl: 400, date: '2026-01-07' });

    const rows = await service.getToday(user.id, '2026-01-07');
    expect(rows).toHaveLength(1);
    expect(rows[0]?.amountMl).toBe(400);
  });
});

describe('WaterTrackingService.delete', () => {
  it('removes the entry and decrements the summary', async () => {
    const user = await createUser(tx);
    const entry = await service.create(user.id, {
      amountMl: 500,
      date: '2026-02-01',
    });

    const result = await service.delete(user.id, entry!.id);
    expect(result).toEqual({ message: 'Deleted' });

    const summary = await loadSummary(user.id, '2026-02-01');
    expect(summary?.totalWaterMl).toBe(0);
  });

  it('throws when the entry does not exist', async () => {
    const user = await createUser(tx);
    expect(service.delete(user.id, randomUUID())).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it("throws when deleting another user's entry", async () => {
    const owner = await createUser(tx);
    const intruder = await createUser(tx);
    const entry = await service.create(owner.id, {
      amountMl: 500,
      date: '2026-02-02',
    });

    expect(service.delete(intruder.id, entry!.id)).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('returns the summary to zero after create then delete', async () => {
    const user = await createUser(tx);
    const entry = await service.create(user.id, {
      amountMl: 700,
      date: '2026-02-03',
    });
    await service.create(user.id, { amountMl: 300, date: '2026-02-03' });

    await service.delete(user.id, entry!.id);

    const summary = await loadSummary(user.id, '2026-02-03');
    expect(summary?.totalWaterMl).toBe(300);
  });
});
