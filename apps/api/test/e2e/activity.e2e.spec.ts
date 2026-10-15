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
const auth = (token: string) => ({ Authorization: `Bearer ${token}` });

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

describe('activity routes', () => {
  it('rejects unauthenticated requests', async () => {
    await http()
      .post('/api/activity/sync')
      .send({ entries: [{ date: '2026-01-01' }] })
      .expect(401);
    await http().get('/api/activity/today').expect(401);
    await http()
      .get('/api/activity/range?from=2026-01-01&to=2026-01-31')
      .expect(401);
  });

  it('syncs activity and persists it for today and range', async () => {
    const token = await register();

    const sync = await http()
      .post('/api/activity/sync')
      .set(auth(token))
      .send({
        entries: [
          {
            date: '2026-01-01',
            steps: 5000,
            activeCalories: 500,
            basalCalories: 1600,
            distanceMeters: 5000.5,
          },
        ],
      })
      .expect(201);
    expect(Array.isArray(sync.body)).toBe(true);
    expect(sync.body).toHaveLength(1);
    expect(sync.body[0].steps).toBe(5000);
    expect(sync.body[0].distanceMeters).toBe('5000.50');

    const today = await http()
      .get('/api/activity/today?date=2026-01-01')
      .set(auth(token))
      .expect(200);
    expect(today.body.steps).toBe(5000);
    expect(today.body.activeCalories).toBe(500);

    const range = await http()
      .get('/api/activity/range?from=2026-01-01&to=2026-01-31')
      .set(auth(token))
      .expect(200);
    expect(range.body).toHaveLength(1);
    expect(range.body[0].date).toBe('2026-01-01');
    expect(range.body[0].caloriesConsumed).toBe(0);
    expect(range.body[0].netCalories).toBe(-500);
  });

  it('returns an empty today summary when no data exists', async () => {
    const token = await register();
    const res = await http()
      .get('/api/activity/today')
      .set(auth(token))
      .expect(200);
    expect(res.body.id).toBeNull();
    expect(res.body.steps).toBe(0);
  });

  it('rejects out-of-range metrics', async () => {
    const token = await register();
    const cases = [
      { steps: 200001 },
      { activeCalories: 20001 },
      { basalCalories: 20001 },
      { distanceMeters: 1000001 },
    ];
    for (const metrics of cases) {
      await http()
        .post('/api/activity/sync')
        .set(auth(token))
        .send({ entries: [{ date: '2026-01-01', ...metrics }] })
        .expect(400);
    }
  });

  it('rejects an empty batch and a batch over 31 entries', async () => {
    const token = await register();
    await http()
      .post('/api/activity/sync')
      .set(auth(token))
      .send({ entries: [] })
      .expect(400);

    const entries = Array.from({ length: 32 }, (_, i) => ({
      date: `2026-01-${String((i % 28) + 1).padStart(2, '0')}`,
    }));
    await http()
      .post('/api/activity/sync')
      .set(auth(token))
      .send({ entries })
      .expect(400);
  });

  it('rejects a missing or inverted range', async () => {
    const token = await register();
    await http().get('/api/activity/range').set(auth(token)).expect(400);
    await http()
      .get('/api/activity/range?from=2026-02-01&to=2026-01-01')
      .set(auth(token))
      .expect(400);
  });

  it('does not duplicate or double metrics on re-sync', async () => {
    const token = await register();
    const body = {
      entries: [{ date: '2026-02-01', steps: 1000, activeCalories: 100 }],
    };

    await http()
      .post('/api/activity/sync')
      .set(auth(token))
      .send(body)
      .expect(201);
    await http()
      .post('/api/activity/sync')
      .set(auth(token))
      .send(body)
      .expect(201);

    const range = await http()
      .get('/api/activity/range?from=2026-02-01&to=2026-02-28')
      .set(auth(token))
      .expect(200);
    expect(range.body).toHaveLength(1);
    expect(range.body[0].steps).toBe(1000);
    expect(range.body[0].netCalories).toBe(-100);
  });

  it('does not expose another user data', async () => {
    const tokenA = await register();
    const tokenB = await register();

    await http()
      .post('/api/activity/sync')
      .set(auth(tokenA))
      .send({ entries: [{ date: '2026-03-01', steps: 111 }] })
      .expect(201);

    const rangeB = await http()
      .get('/api/activity/range?from=2026-03-01&to=2026-03-31')
      .set(auth(tokenB))
      .expect(200);
    expect(rangeB.body).toHaveLength(0);
  });
});
