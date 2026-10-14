import { afterAll, beforeAll, describe, expect, it } from 'bun:test';
import { ConfigModule } from '@nestjs/config';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { eq } from 'drizzle-orm';

import { DbModule } from '../../src/db/db.module';
import { userGoals } from '../../src/db/schema/userGoals';
import { userProfiles } from '../../src/db/schema/userProfiles';
import { weightLogs } from '../../src/db/schema/weightLogs';
import { WeightLogsModule } from '../../src/weight-logs/weight-logs.module';
import { WeightLogsService } from '../../src/weight-logs/weight-logs.service';
import { formatDateInTimeZone } from '../../src/common/time/user-date';
import { createTestModule } from '../utils/app';
import { createTestDb } from '../utils/db';
import type { TestDb, TestTx } from '../utils/db';
import { createProfile, createUser } from '../utils/seed';

let db: TestDb;
let tx: TestTx;
let rollback: () => Promise<void>;
let service: WeightLogsService;

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
        WeightLogsModule,
      ],
    },
    tx,
  );
  service = moduleRef.get(WeightLogsService);
});

afterAll(async () => {
  await rollback();
  await db.close();
});

const TODAY = formatDateInTimeZone(new Date(), 'UTC');

async function loadProfileWeight(userId: string) {
  const [row] = await tx
    .select()
    .from(userProfiles)
    .where(eq(userProfiles.userId, userId));
  return row;
}

async function loadLogs(userId: string) {
  return tx.select().from(weightLogs).where(eq(weightLogs.userId, userId));
}

describe('WeightLogsService.record', () => {
  it('throws when the profile is missing', async () => {
    const user = await createUser(tx);
    expect(service.record(user.id, { weightKg: 70 })).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it("updates the profile weight and recalculates goals for today's entry", async () => {
    const user = await createUser(tx);
    await createProfile(tx, user.id, { weight: 80 });

    const log = (await service.record(user.id, { weightKg: 82 }))!;

    expect(log.source).toBe('manual');
    expect(log.entryDate).toBe(TODAY);
    expect(await loadProfileWeight(user.id)).toMatchObject({ weight: 82 });

    const [goals] = await tx
      .select()
      .from(userGoals)
      .where(eq(userGoals.userId, user.id));
    expect(goals?.source).toBe('initial');
  });

  it('does not change the current weight for a backfilled date', async () => {
    const user = await createUser(tx);
    await createProfile(tx, user.id, { weight: 80 });

    await service.record(user.id, { weightKg: 70, date: '2020-01-01' });

    expect(await loadProfileWeight(user.id)).toMatchObject({ weight: 80 });
    const [goals] = await tx
      .select()
      .from(userGoals)
      .where(eq(userGoals.userId, user.id));
    expect(goals).toBeUndefined();
  });

  it('upserts a second entry on the same date', async () => {
    const user = await createUser(tx);
    await createProfile(tx, user.id, { weight: 80 });

    await service.record(user.id, { weightKg: 80, date: '2026-01-10' });
    await service.record(user.id, { weightKg: 81, date: '2026-01-10' });

    const logs = await loadLogs(user.id);
    expect(logs).toHaveLength(1);
    expect(Number(logs[0]?.weightKg)).toBe(81);
  });

  it('keeps the initial source when correcting its date', async () => {
    const user = await createUser(tx);
    await createProfile(tx, user.id, { weight: 80 });
    await tx.insert(weightLogs).values({
      userId: user.id,
      weightKg: '80',
      entryDate: '2026-01-15',
      source: 'initial',
    });

    const log = (await service.record(user.id, {
      weightKg: 79,
      date: '2026-01-15',
    }))!;

    expect(log.source).toBe('initial');
    expect(Number(log.weightKg)).toBe(79);
  });
});

describe('WeightLogsService.findByRange', () => {
  it('returns only logs inside the range, ordered by date', async () => {
    const user = await createUser(tx);
    await createProfile(tx, user.id);
    await service.record(user.id, { weightKg: 80, date: '2026-02-05' });
    await service.record(user.id, { weightKg: 81, date: '2026-02-01' });
    await service.record(user.id, { weightKg: 82, date: '2026-02-20' });

    const rows = await service.findByRange(user.id, {
      from: '2026-02-01',
      to: '2026-02-10',
    });

    expect(rows.map((r) => r.entryDate)).toEqual(['2026-02-01', '2026-02-05']);
  });

  it('returns every log when no range is given', async () => {
    const user = await createUser(tx);
    await createProfile(tx, user.id);
    await service.record(user.id, { weightKg: 80, date: '2026-03-01' });
    await service.record(user.id, { weightKg: 81, date: '2026-03-02' });

    expect(await service.findByRange(user.id)).toHaveLength(2);
  });
});

describe('WeightLogsService.remove', () => {
  it('throws when the profile is missing', async () => {
    const user = await createUser(tx);
    expect(service.remove(user.id, '2026-01-01')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('throws for a missing record', async () => {
    const user = await createUser(tx);
    await createProfile(tx, user.id);
    expect(service.remove(user.id, '2026-01-01')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('refuses to delete the initial record', async () => {
    const user = await createUser(tx);
    await createProfile(tx, user.id);
    await tx.insert(weightLogs).values({
      userId: user.id,
      weightKg: '80',
      entryDate: '2026-01-01',
      source: 'initial',
    });

    expect(service.remove(user.id, '2026-01-01')).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });

  it("reverts the current weight to the previous log when today's entry is removed", async () => {
    const user = await createUser(tx);
    await createProfile(tx, user.id, { weight: 80 });
    await tx.insert(weightLogs).values({
      userId: user.id,
      weightKg: '78',
      entryDate: '2025-12-31',
      source: 'initial',
    });
    await service.record(user.id, { weightKg: 85, date: TODAY });

    const result = await service.remove(user.id, TODAY);
    expect(result).toEqual({ message: 'Weight log removed' });

    expect(await loadProfileWeight(user.id)).toMatchObject({ weight: 78 });
    expect(await loadLogs(user.id)).toHaveLength(1);
  });
});
