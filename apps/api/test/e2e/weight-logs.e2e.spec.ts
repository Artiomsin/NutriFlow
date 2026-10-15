import { afterAll, beforeAll, describe, expect, it } from 'bun:test';
import { randomUUID } from 'node:crypto';
import type { INestApplication } from '@nestjs/common';
import request from 'supertest';

import { createE2eApp } from '../utils/e2e';
import { createTestDb } from '../utils/db';
import type { TestDb } from '../utils/db';

let db: TestDb;
let rollback: () => Promise<void>;
let app: INestApplication;

beforeAll(async () => {
  db = createTestDb();
  const opened = await db.openTx();
  rollback = opened.rollback;
  app = await createE2eApp(opened.tx);
});

afterAll(async () => {
  await app.close();
  await rollback();
  await db.close();
});

const http = () => request(app.getHttpServer());
const PAST = '2026-10-06';

async function register(): Promise<string> {
  const res = await http()
    .post('/api/auth/register')
    .send({
      email: `${randomUUID()}@test.com`,
      password: 'secret1',
      firstName: 'Ann',
      lastName: 'Lee',
    })
    .expect(201);
  return (res.body as { accessToken: string }).accessToken;
}

const auth = (token: string) => ({ Authorization: `Bearer ${token}` });

async function createProfile(token: string): Promise<void> {
  await http()
    .post('/api/profiles')
    .set(auth(token))
    .send({
      weight: 80,
      height: 180,
      age: 30,
      gender: 'male',
      goal: 'maintain',
      activityLevel: 'medium',
    })
    .expect(201);
}

const listLogs = async (token: string) => {
  const res = await http().get('/api/weight-logs').set(auth(token)).expect(200);
  return res.body as Array<{
    entryDate: string;
    source: string;
    weightKg: number;
  }>;
};

describe('weight-logs routes', () => {
  it('rejects an unauthenticated create', async () => {
    await http().post('/api/weight-logs').send({ weightKg: 75 }).expect(401);
  });

  it('rejects an out-of-range weight', async () => {
    const token = await register();
    await http()
      .post('/api/weight-logs')
      .set(auth(token))
      .send({ weightKg: 19 })
      .expect(400);
    await http()
      .post('/api/weight-logs')
      .set(auth(token))
      .send({ weightKg: 401 })
      .expect(400);
  });

  it('requires a profile to record', async () => {
    const token = await register();
    await http()
      .post('/api/weight-logs')
      .set(auth(token))
      .send({ weightKg: 75 })
      .expect(404);
  });

  it('records a backfilled log and lists it', async () => {
    const token = await register();
    await createProfile(token);

    const created = await http()
      .post('/api/weight-logs')
      .set(auth(token))
      .send({ weightKg: 75, date: PAST })
      .expect(201);
    expect(created.body.entryDate).toBe(PAST);
    expect(created.body.source).toBe('manual');

    const logs = await listLogs(token);
    expect(logs.some((log) => log.entryDate === PAST)).toBeTrue();
  });

  it('validates the range query', async () => {
    const token = await register();
    await http()
      .get('/api/weight-logs?from=2026-10-10&to=2026-10-01')
      .set(auth(token))
      .expect(400);
  });

  it('rejects a malformed date param', async () => {
    const token = await register();
    await http()
      .delete('/api/weight-logs/not-a-date')
      .set(auth(token))
      .expect(400);
    await http()
      .delete('/api/weight-logs/2026-02-30')
      .set(auth(token))
      .expect(400);
  });

  it('returns 404 for an unknown date', async () => {
    const token = await register();
    await createProfile(token);
    await http()
      .delete('/api/weight-logs/2020-01-01')
      .set(auth(token))
      .expect(404);
  });

  it('deletes a manual log but refuses the initial one', async () => {
    const token = await register();
    await createProfile(token);

    const initial = (await listLogs(token)).find(
      (log) => log.source === 'initial',
    );
    expect(initial).toBeDefined();
    await http()
      .delete(`/api/weight-logs/${initial!.entryDate}`)
      .set(auth(token))
      .expect(400);

    await http()
      .post('/api/weight-logs')
      .set(auth(token))
      .send({ weightKg: 75, date: PAST })
      .expect(201);
    const removed = await http()
      .delete(`/api/weight-logs/${PAST}`)
      .set(auth(token))
      .expect(200);
    expect(removed.body.message).toBeString();
  });
});
