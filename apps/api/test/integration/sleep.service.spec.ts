import { afterAll, beforeAll, describe, expect, it } from 'bun:test';
import { ConfigModule } from '@nestjs/config';
import { eq } from 'drizzle-orm';

import { DbModule } from '../../src/db/db.module';
import { userSleep } from '../../src/db/schema/userSleep';
import { SleepModule } from '../../src/sleep/sleep.module';
import { SleepService } from '../../src/sleep/sleep.service';
import { createTestModule } from '../utils/app';
import { createTestDb } from '../utils/db';
import type { TestDb, TestTx } from '../utils/db';
import { createSleepNight, createUser } from '../utils/seed';

let db: TestDb;
let tx: TestTx;
let rollback: () => Promise<void>;
let service: SleepService;

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
        SleepModule,
      ],
    },
    tx,
  );
  service = moduleRef.get(SleepService);
});

afterAll(async () => {
  await rollback();
  await db.close();
});

const night = (start: string, localDate: string) => ({
  startDate: start,
  endDate: new Date(new Date(start).getTime() + 8 * 3_600_000).toISOString(),
  localDate,
});

describe('SleepService.sync', () => {
  it('inserts every night and returns the count', async () => {
    const user = await createUser(tx);

    const result = await service.sync(user.id, {
      nights: [
        {
          ...night('2026-01-01T22:00:00.000Z', '2026-01-02'),
          asleepSeconds: 25_000,
          efficiency: 90,
        },
        night('2026-01-02T22:00:00.000Z', '2026-01-03'),
      ],
    });

    expect(result).toEqual({ synced: 2 });
    const rows = await tx
      .select()
      .from(userSleep)
      .where(eq(userSleep.userId, user.id));
    expect(rows).toHaveLength(2);
  });

  it('upserts an existing night keyed by its start date', async () => {
    const user = await createUser(tx);
    const first = {
      ...night('2026-01-01T22:00:00.000Z', '2026-01-02'),
      asleepSeconds: 20_000,
    };

    await service.sync(user.id, { nights: [first] });
    await service.sync(user.id, {
      nights: [{ ...first, asleepSeconds: 26_000 }],
    });

    const rows = await tx
      .select()
      .from(userSleep)
      .where(eq(userSleep.userId, user.id));
    expect(rows).toHaveLength(1);
    expect(Number(rows[0]!.asleepSeconds)).toBe(26_000);
  });

  it('keeps the metrics null when they are omitted', async () => {
    const user = await createUser(tx);

    await service.sync(user.id, {
      nights: [night('2026-01-01T22:00:00.000Z', '2026-01-02')],
    });

    const [row] = await tx
      .select()
      .from(userSleep)
      .where(eq(userSleep.userId, user.id));
    expect(row!.asleepSeconds).toBeNull();
    expect(row!.efficiency).toBeNull();
    expect(row!.awakenings).toBeNull();
  });
});

describe('SleepService.deleteMissing', () => {
  const window = {
    start: '2026-01-01T00:00:00.000Z',
    end: '2026-01-31T00:00:00.000Z',
  };

  it('deletes nights inside the window that are not kept', async () => {
    const user = await createUser(tx);
    await createSleepNight(tx, user.id, {
      startDate: new Date('2026-01-01T22:00:00.000Z'),
      endDate: new Date('2026-01-02T06:00:00.000Z'),
      localDate: '2026-01-02',
    });
    await createSleepNight(tx, user.id, {
      startDate: new Date('2026-01-02T22:00:00.000Z'),
      endDate: new Date('2026-01-03T06:00:00.000Z'),
      localDate: '2026-01-03',
    });

    const result = await service.deleteMissing(
      user.id,
      window.start,
      window.end,
      ['2026-01-02T22:00:00.000Z'],
    );

    expect(result).toEqual({ deleted: 1 });
    const rows = await tx
      .select()
      .from(userSleep)
      .where(eq(userSleep.userId, user.id));
    expect(rows).toHaveLength(1);
    expect(rows[0]!.startDate.toISOString()).toBe('2026-01-02T22:00:00.000Z');
  });

  it('deletes every night in the window when nothing is kept', async () => {
    const user = await createUser(tx);
    for (const day of ['2026-01-01', '2026-01-02']) {
      const next = String(Number(day.slice(-2)) + 1).padStart(2, '0');
      await createSleepNight(tx, user.id, {
        startDate: new Date(`${day}T22:00:00.000Z`),
        endDate: new Date(`2026-01-${next}T06:00:00.000Z`),
        localDate: day,
      });
    }

    const result = await service.deleteMissing(
      user.id,
      window.start,
      window.end,
      [],
    );

    expect(result).toEqual({ deleted: 2 });
  });

  it('keeps rows outside the window and deletes rows on the inclusive edges', async () => {
    const user = await createUser(tx);
    const edges = [
      '2025-12-31T23:59:59.999Z',
      '2026-01-01T00:00:00.000Z',
      '2026-01-31T00:00:00.000Z',
      '2026-01-31T00:00:00.001Z',
    ];
    for (const start of edges) {
      const startDate = new Date(start);
      await createSleepNight(tx, user.id, {
        startDate,
        endDate: new Date(startDate.getTime() + 8 * 3_600_000),
        localDate: start.slice(0, 10),
      });
    }

    const result = await service.deleteMissing(
      user.id,
      window.start,
      window.end,
      [],
    );

    expect(result).toEqual({ deleted: 2 });
    const rows = await tx
      .select({ startDate: userSleep.startDate })
      .from(userSleep)
      .where(eq(userSleep.userId, user.id));
    const remaining = rows.map((row) => row.startDate.toISOString()).sort();
    expect(remaining).toEqual([
      '2025-12-31T23:59:59.999Z',
      '2026-01-31T00:00:00.001Z',
    ]);
  });

  it('keeps several retained nights and deletes the rest in the window', async () => {
    const user = await createUser(tx);
    for (const start of ['2026-01-01', '2026-01-02', '2026-01-03']) {
      await createSleepNight(tx, user.id, {
        startDate: new Date(`${start}T22:00:00.000Z`),
        endDate: new Date(`${start}T23:00:00.000Z`),
        localDate: start,
      });
    }

    const result = await service.deleteMissing(
      user.id,
      window.start,
      window.end,
      ['2026-01-01T22:00:00.000Z', '2026-01-03T22:00:00.000Z'],
    );

    expect(result).toEqual({ deleted: 1 });
    const rows = await tx
      .select()
      .from(userSleep)
      .where(eq(userSleep.userId, user.id));
    expect(rows.map((row) => row.startDate.toISOString()).sort()).toEqual([
      '2026-01-01T22:00:00.000Z',
      '2026-01-03T22:00:00.000Z',
    ]);
  });

  it('does not delete nights belonging to another user', async () => {
    const user = await createUser(tx);
    const other = await createUser(tx);
    const startDate = new Date('2026-01-05T22:00:00.000Z');
    const endDate = new Date('2026-01-06T06:00:00.000Z');
    await createSleepNight(tx, user.id, {
      startDate,
      endDate,
      localDate: '2026-01-06',
    });
    await createSleepNight(tx, other.id, {
      startDate,
      endDate,
      localDate: '2026-01-06',
    });

    const result = await service.deleteMissing(
      user.id,
      window.start,
      window.end,
      [],
    );

    expect(result).toEqual({ deleted: 1 });
    const otherRows = await tx
      .select()
      .from(userSleep)
      .where(eq(userSleep.userId, other.id));
    expect(otherRows).toHaveLength(1);
  });
});

describe('SleepService.getHistory', () => {
  it('orders nights by start date and maps numeric metrics', async () => {
    const user = await createUser(tx);
    await createSleepNight(tx, user.id, {
      startDate: new Date('2026-01-01T22:00:00.000Z'),
      endDate: new Date('2026-01-02T06:00:00.000Z'),
      localDate: '2026-01-02',
      asleepSeconds: '25000.0',
      efficiency: '90.00',
    });
    await createSleepNight(tx, user.id, {
      startDate: new Date('2026-01-02T22:00:00.000Z'),
      endDate: new Date('2026-01-03T06:00:00.000Z'),
      localDate: '2026-01-03',
    });

    const { total, nights } = await service.getHistory(user.id);

    expect(total).toBe(2);
    expect(nights.map((entry) => entry.localDate)).toEqual([
      '2026-01-03',
      '2026-01-02',
    ]);
    expect(nights[1]!.asleepSeconds).toBe(25_000);
    expect(nights[1]!.efficiency).toBe(90);
    expect(nights[0]!.asleepSeconds).toBeNull();
    expect(nights[0]!.efficiency).toBeNull();
  });

  it('filters by the local date range', async () => {
    const user = await createUser(tx);
    await createSleepNight(tx, user.id, {
      startDate: new Date('2026-01-01T22:00:00.000Z'),
      endDate: new Date('2026-01-02T06:00:00.000Z'),
      localDate: '2026-01-02',
    });
    await createSleepNight(tx, user.id, {
      startDate: new Date('2026-02-01T22:00:00.000Z'),
      endDate: new Date('2026-02-02T06:00:00.000Z'),
      localDate: '2026-02-02',
    });

    const { total, nights } = await service.getHistory(
      user.id,
      '2026-01-01',
      '2026-01-31',
    );

    expect(total).toBe(1);
    expect(nights[0]!.localDate).toBe('2026-01-02');
  });

  it('paginates with limit and offset', async () => {
    const user = await createUser(tx);
    for (let day = 1; day <= 3; day += 1) {
      await createSleepNight(tx, user.id, {
        startDate: new Date(`2026-01-0${day}T22:00:00.000Z`),
        endDate: new Date(`2026-01-0${day + 1}T06:00:00.000Z`),
        localDate: `2026-01-0${day + 1}`,
      });
    }

    const { total, nights } = await service.getHistory(
      user.id,
      undefined,
      undefined,
      1,
      1,
    );

    expect(total).toBe(3);
    expect(nights).toHaveLength(1);
    expect(nights[0]!.localDate).toBe('2026-01-03');
  });

  it('supports one-sided date filters', async () => {
    const user = await createUser(tx);
    for (const localDate of ['2026-01-02', '2026-02-02', '2026-03-02']) {
      await createSleepNight(tx, user.id, {
        startDate: new Date(`${localDate}T22:00:00.000Z`),
        endDate: new Date(`${localDate}T23:00:00.000Z`),
        localDate,
      });
    }

    const fromOnly = await service.getHistory(user.id, '2026-02-01');
    const toOnly = await service.getHistory(user.id, undefined, '2026-02-15');

    expect(fromOnly.total).toBe(2);
    expect(toOnly.total).toBe(2);
  });

  it('only returns the nights of the given user', async () => {
    const user = await createUser(tx);
    const other = await createUser(tx);
    await createSleepNight(tx, user.id, {
      startDate: new Date('2026-01-01T22:00:00.000Z'),
      endDate: new Date('2026-01-02T06:00:00.000Z'),
      localDate: '2026-01-02',
    });
    await createSleepNight(tx, other.id, {
      startDate: new Date('2026-01-01T22:00:00.000Z'),
      endDate: new Date('2026-01-02T06:00:00.000Z'),
      localDate: '2026-01-02',
    });

    const { total, nights } = await service.getHistory(user.id);

    expect(total).toBe(1);
    expect(nights).toHaveLength(1);
  });
});
