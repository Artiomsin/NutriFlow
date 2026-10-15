import { afterAll, beforeAll, describe, expect, it } from 'bun:test';
import { ConfigModule } from '@nestjs/config';
import { eq } from 'drizzle-orm';

import { DbModule } from '../../src/db/db.module';
import { userWorkouts } from '../../src/db/schema/userWorkouts';
import { WorkoutsModule } from '../../src/workouts/workouts.module';
import { WorkoutsService } from '../../src/workouts/workouts.service';
import { createTestModule } from '../utils/app';
import { createTestDb } from '../utils/db';
import type { TestDb, TestTx } from '../utils/db';
import { createUser, createWorkout } from '../utils/seed';

let db: TestDb;
let tx: TestTx;
let rollback: () => Promise<void>;
let service: WorkoutsService;

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
        WorkoutsModule,
      ],
    },
    tx,
  );
  service = moduleRef.get(WorkoutsService);
});

afterAll(async () => {
  await rollback();
  await db.close();
});

const workout = (healthKitWorkoutId: string) => ({
  healthKitWorkoutId,
  type: 'running',
  startDate: '2026-01-01T10:00:00.000Z',
  endDate: '2026-01-01T10:30:00.000Z',
  localDate: '2026-01-01',
  durationSeconds: 1_800,
});

describe('WorkoutsService.sync', () => {
  it('inserts every workout and returns the count', async () => {
    const user = await createUser(tx);

    const result = await service.sync(user.id, {
      workouts: [workout('HK-1'), workout('HK-2')],
    });

    expect(result).toEqual({ synced: 2 });
    const rows = await tx
      .select()
      .from(userWorkouts)
      .where(eq(userWorkouts.userId, user.id));
    expect(rows).toHaveLength(2);
  });

  it('defaults details and leaves optional metrics null', async () => {
    const user = await createUser(tx);

    await service.sync(user.id, { workouts: [workout('HK-3')] });

    const [row] = await tx
      .select()
      .from(userWorkouts)
      .where(eq(userWorkouts.userId, user.id));
    expect(row!.details).toEqual({});
    expect(row!.caloriesBurned).toBeNull();
    expect(row!.heartRateAvg).toBeNull();
  });

  it('upserts on the (user, health kit id) key', async () => {
    const user = await createUser(tx);

    await service.sync(user.id, { workouts: [workout('HK-1')] });
    await service.sync(user.id, {
      workouts: [{ ...workout('HK-1'), durationSeconds: 2_400 }],
    });

    const rows = await tx
      .select()
      .from(userWorkouts)
      .where(eq(userWorkouts.userId, user.id));

    expect(rows).toHaveLength(1);
    expect(Number(rows[0]!.durationSeconds)).toBe(2_400);
  });
});

describe('WorkoutsService.deleteMissing', () => {
  const start = '2026-01-01T00:00:00.000Z';
  const end = '2026-01-31T00:00:00.000Z';

  it('deletes workouts in the window not present in the kept ids', async () => {
    const user = await createUser(tx);
    await createWorkout(tx, user.id, {
      healthKitWorkoutId: 'HK-KEEP',
      startDate: new Date('2026-01-01T10:00:00.000Z'),
      endDate: new Date('2026-01-01T10:30:00.000Z'),
      localDate: '2026-01-01',
    });
    await createWorkout(tx, user.id, {
      healthKitWorkoutId: 'HK-DROP',
      startDate: new Date('2026-01-02T10:00:00.000Z'),
      endDate: new Date('2026-01-02T10:30:00.000Z'),
      localDate: '2026-01-02',
    });

    const result = await service.deleteMissing(user.id, start, end, [
      'HK-KEEP',
    ]);

    expect(result).toEqual({ deleted: 1 });
    const rows = await tx
      .select()
      .from(userWorkouts)
      .where(eq(userWorkouts.userId, user.id));
    expect(rows[0]!.healthKitWorkoutId).toBe('HK-KEEP');
  });

  it('deletes every workout in the window when nothing is kept', async () => {
    const user = await createUser(tx);
    await createWorkout(tx, user.id, {
      healthKitWorkoutId: 'HK-1',
      startDate: new Date('2026-01-01T10:00:00.000Z'),
      endDate: new Date('2026-01-01T10:30:00.000Z'),
      localDate: '2026-01-01',
    });

    const result = await service.deleteMissing(user.id, start, end, []);

    expect(result).toEqual({ deleted: 1 });
  });

  it('treats both window edges as inclusive', async () => {
    const user = await createUser(tx);
    const edges = [
      { start: '2025-12-31T23:59:59.999Z', id: 'HK-BEFORE' },
      { start: '2026-01-01T00:00:00.000Z', id: 'HK-START' },
      { start: '2026-01-31T00:00:00.000Z', id: 'HK-END' },
      { start: '2026-01-31T00:00:00.001Z', id: 'HK-AFTER' },
    ];
    for (const edge of edges) {
      const startDate = new Date(edge.start);
      await createWorkout(tx, user.id, {
        healthKitWorkoutId: edge.id,
        startDate,
        endDate: new Date(startDate.getTime() + 30 * 60_000),
        localDate: edge.start.slice(0, 10),
      });
    }

    const result = await service.deleteMissing(user.id, start, end, []);

    expect(result).toEqual({ deleted: 2 });
    const rows = await tx
      .select({ startDate: userWorkouts.startDate })
      .from(userWorkouts)
      .where(eq(userWorkouts.userId, user.id));
    const remaining = rows.map((row) => row.startDate.toISOString()).sort();
    expect(remaining).toEqual([
      '2025-12-31T23:59:59.999Z',
      '2026-01-31T00:00:00.001Z',
    ]);
  });

  it('does not delete workouts belonging to another user', async () => {
    const user = await createUser(tx);
    const other = await createUser(tx);
    const startDate = new Date('2026-01-05T10:00:00.000Z');
    const endDate = new Date('2026-01-05T11:00:00.000Z');
    await createWorkout(tx, user.id, {
      healthKitWorkoutId: 'HK-A',
      startDate,
      endDate,
      localDate: '2026-01-05',
    });
    await createWorkout(tx, other.id, {
      healthKitWorkoutId: 'HK-B',
      startDate,
      endDate,
      localDate: '2026-01-05',
    });

    const result = await service.deleteMissing(user.id, start, end, []);

    expect(result).toEqual({ deleted: 1 });
    const otherRows = await tx
      .select()
      .from(userWorkouts)
      .where(eq(userWorkouts.userId, other.id));
    expect(otherRows).toHaveLength(1);
  });
});

describe('WorkoutsService.getHistory', () => {
  it('filters by the start date range and maps numeric metrics', async () => {
    const user = await createUser(tx);
    await createWorkout(tx, user.id, {
      healthKitWorkoutId: 'HK-1',
      startDate: new Date('2026-01-01T10:00:00.000Z'),
      endDate: new Date('2026-01-01T10:30:00.000Z'),
      localDate: '2026-01-01',
      durationSeconds: '1800',
      caloriesBurned: '320.5',
    });
    await createWorkout(tx, user.id, {
      healthKitWorkoutId: 'HK-2',
      startDate: new Date('2026-02-01T10:00:00.000Z'),
      endDate: new Date('2026-02-01T10:30:00.000Z'),
      localDate: '2026-02-01',
    });

    const { total, workouts } = await service.getHistory(
      user.id,
      '2026-01-01',
      '2026-01-31',
    );

    expect(total).toBe(1);
    expect(workouts[0]!.durationSeconds).toBe(1_800);
    expect(workouts[0]!.caloriesBurned).toBe(320.5);
  });

  it('orders by start date descending', async () => {
    const user = await createUser(tx);
    await createWorkout(tx, user.id, {
      healthKitWorkoutId: 'HK-EARLY',
      startDate: new Date('2026-01-01T10:00:00.000Z'),
      endDate: new Date('2026-01-01T10:30:00.000Z'),
      localDate: '2026-01-01',
    });
    await createWorkout(tx, user.id, {
      healthKitWorkoutId: 'HK-LATE',
      startDate: new Date('2026-01-05T10:00:00.000Z'),
      endDate: new Date('2026-01-05T10:30:00.000Z'),
      localDate: '2026-01-05',
    });

    const { workouts } = await service.getHistory(user.id);

    expect(workouts.map((row) => row.healthKitWorkoutId)).toEqual([
      'HK-LATE',
      'HK-EARLY',
    ]);
  });

  it('supports one-sided date filters', async () => {
    const user = await createUser(tx);
    for (const day of ['2026-01-05', '2026-02-05', '2026-03-05']) {
      await createWorkout(tx, user.id, {
        healthKitWorkoutId: `HK-${day}`,
        startDate: new Date(`${day}T10:00:00.000Z`),
        endDate: new Date(`${day}T11:00:00.000Z`),
        localDate: day,
      });
    }

    const fromOnly = await service.getHistory(user.id, '2026-02-01');
    const toOnly = await service.getHistory(user.id, undefined, '2026-02-15');

    expect(fromOnly.total).toBe(2);
    expect(toOnly.total).toBe(2);
  });

  it('includes a workout on the last millisecond of the range', async () => {
    const user = await createUser(tx);
    await createWorkout(tx, user.id, {
      healthKitWorkoutId: 'HK-EDGE',
      startDate: new Date('2026-01-31T23:59:59.999Z'),
      endDate: new Date('2026-02-01T00:00:00.999Z'),
      localDate: '2026-01-31',
    });
    await createWorkout(tx, user.id, {
      healthKitWorkoutId: 'HK-NEXT-DAY',
      startDate: new Date('2026-02-01T00:00:00.000Z'),
      endDate: new Date('2026-02-01T01:00:00.000Z'),
      localDate: '2026-02-01',
    });

    const { total, workouts } = await service.getHistory(
      user.id,
      '2026-01-01',
      '2026-01-31',
    );

    expect(total).toBe(1);
    expect(workouts[0]!.healthKitWorkoutId).toBe('HK-EDGE');
  });

  it('maps missing optional metrics to null and details to an object', async () => {
    const user = await createUser(tx);
    await createWorkout(tx, user.id, {
      healthKitWorkoutId: 'HK-1',
      startDate: new Date('2026-01-01T10:00:00.000Z'),
      endDate: new Date('2026-01-01T11:00:00.000Z'),
      localDate: '2026-01-01',
    });

    const { workouts } = await service.getHistory(user.id);

    expect(workouts[0]!.caloriesBurned).toBeNull();
    expect(workouts[0]!.heartRateAvg).toBeNull();
    expect(workouts[0]!.details).toEqual({});
  });

  it('only returns the workouts of the given user', async () => {
    const user = await createUser(tx);
    const other = await createUser(tx);
    const startDate = new Date('2026-01-01T10:00:00.000Z');
    const endDate = new Date('2026-01-01T11:00:00.000Z');
    await createWorkout(tx, user.id, {
      healthKitWorkoutId: 'HK-A',
      startDate,
      endDate,
      localDate: '2026-01-01',
    });
    await createWorkout(tx, other.id, {
      healthKitWorkoutId: 'HK-B',
      startDate,
      endDate,
      localDate: '2026-01-01',
    });

    const { total } = await service.getHistory(user.id);

    expect(total).toBe(1);
  });
});
