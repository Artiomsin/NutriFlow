import { afterAll, beforeAll, describe, expect, it } from 'bun:test';
import { ConfigModule } from '@nestjs/config';
import { NotFoundException } from '@nestjs/common';
import { and, eq } from 'drizzle-orm';

import { DbModule } from '../../src/db/db.module';
import { userGoals } from '../../src/db/schema/userGoals';
import { userProfiles } from '../../src/db/schema/userProfiles';
import { weightLogs } from '../../src/db/schema/weightLogs';
import { ProfilesModule } from '../../src/profiles/profiles.module';
import { ProfilesService } from '../../src/profiles/profiles.service';
import { formatDateInTimeZone } from '../../src/common/time/user-date';
import { createTestModule } from '../utils/app';
import { createTestDb } from '../utils/db';
import type { TestDb, TestTx } from '../utils/db';
import { createUser } from '../utils/seed';

let db: TestDb;
let tx: TestTx;
let rollback: () => Promise<void>;
let service: ProfilesService;

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
        ProfilesModule,
      ],
    },
    tx,
  );
  service = moduleRef.get(ProfilesService);
});

afterAll(async () => {
  await rollback();
  await db.close();
});

const profileInput = {
  weight: 80,
  height: 180,
  age: 30,
  gender: 'male' as const,
  goal: 'maintain' as const,
  activityLevel: 'medium' as const,
};

async function loadWeightLogs(userId: string) {
  return tx.select().from(weightLogs).where(eq(weightLogs.userId, userId));
}

describe('ProfilesService.create', () => {
  it('creates the profile, an initial weight log and calculated goals', async () => {
    const user = await createUser(tx);
    const profile = await service.create({ ...profileInput, userId: user.id });

    expect(profile.userId).toBe(user.id);
    expect(profile.timeZone).toBe('UTC');

    const logs = await loadWeightLogs(user.id);
    expect(logs).toHaveLength(1);
    expect(logs[0]?.source).toBe('initial');
    expect(Number(logs[0]?.weightKg)).toBe(80);
    expect(logs[0]?.entryDate).toBe(formatDateInTimeZone(new Date(), 'UTC'));

    const [goals] = await tx
      .select()
      .from(userGoals)
      .where(eq(userGoals.userId, user.id));
    expect(goals?.source).toBe('initial');
    expect(goals?.dailyCaloriesGoal).toBe(2759);
  });

  it('is idempotent on a repeated POST', async () => {
    const user = await createUser(tx);
    const first = await service.create({ ...profileInput, userId: user.id });
    const second = await service.create({ ...profileInput, userId: user.id });

    expect(second.id).toBe(first.id);
    expect(await loadWeightLogs(user.id)).toHaveLength(1);
  });

  it('honours a provided time zone for the initial log date', async () => {
    const user = await createUser(tx);
    const profile = await service.create({
      ...profileInput,
      userId: user.id,
      timeZone: 'Pacific/Kiritimati',
    });

    expect(profile.timeZone).toBe('Pacific/Kiritimati');
    const logs = await loadWeightLogs(user.id);
    expect(logs[0]?.entryDate).toBe(
      formatDateInTimeZone(new Date(), 'Pacific/Kiritimati'),
    );
  });
});

describe('ProfilesService.findByUserId', () => {
  it('throws when the profile is missing', async () => {
    const user = await createUser(tx);
    expect(service.findByUserId(user.id)).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('returns the stored profile', async () => {
    const user = await createUser(tx);
    await service.create({ ...profileInput, userId: user.id });

    const profile = await service.findByUserId(user.id);
    expect(profile.userId).toBe(user.id);
  });
});

describe('ProfilesService.updateByUserId', () => {
  it('throws when the profile is missing', async () => {
    const user = await createUser(tx);
    expect(service.updateByUserId(user.id, { age: 40 })).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('updates the provided fields and recalculates goals', async () => {
    const user = await createUser(tx);
    await service.create({ ...profileInput, userId: user.id });

    const updated = (await service.updateByUserId(user.id, {
      goal: 'lose',
      age: 31,
    }))!;

    expect(updated.goal).toBe('lose');
    expect(updated.age).toBe(31);

    const [goals] = await tx
      .select()
      .from(userGoals)
      .where(eq(userGoals.userId, user.id));
    expect(goals?.source).toBe('initial');
  });
});

describe('ProfilesService.updateTimeZone', () => {
  it('throws when the profile is missing', async () => {
    const user = await createUser(tx);
    expect(
      service.updateTimeZone(user.id, 'Europe/Paris'),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('updates the time zone', async () => {
    const user = await createUser(tx);
    await service.create({ ...profileInput, userId: user.id });

    const updated = await service.updateTimeZone(user.id, 'Europe/Paris');
    expect(updated.timeZone).toBe('Europe/Paris');
  });
});

describe('ProfilesService.deleteByUserId', () => {
  it('throws when the profile is missing', async () => {
    const user = await createUser(tx);
    expect(service.deleteByUserId(user.id)).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('deletes the profile', async () => {
    const user = await createUser(tx);
    await service.create({ ...profileInput, userId: user.id });

    const result = await service.deleteByUserId(user.id);
    expect(result).toEqual({ message: 'Profile deleted' });

    const [row] = await tx
      .select()
      .from(userProfiles)
      .where(and(eq(userProfiles.userId, user.id)));
    expect(row).toBeUndefined();
  });
});
