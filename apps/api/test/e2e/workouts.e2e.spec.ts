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

const WORKOUT = {
  healthKitWorkoutId: 'hk-1',
  type: 'running',
  startDate: '2026-01-01T10:00:00.000Z',
  endDate: '2026-01-01T11:00:00.000Z',
  localDate: '2026-01-01',
  durationSeconds: 3600,
  caloriesBurned: 400,
};

function manyWorkouts(count: number) {
  return Array.from({ length: count }, (_, i) => {
    const start = new Date(Date.UTC(2026, 0, 1, 0, i % 60));
    return {
      ...WORKOUT,
      healthKitWorkoutId: `hk-${i}`,
      startDate: start.toISOString(),
      endDate: new Date(start.getTime() + 3_600_000).toISOString(),
    };
  });
}

describe('workouts routes', () => {
  it('rejects unauthenticated requests', async () => {
    await http()
      .post('/api/workouts/sync')
      .send({ workouts: [WORKOUT] })
      .expect(401);
    await http().get('/api/workouts').expect(401);
    await http()
      .delete('/api/workouts/missing')
      .send({
        startDate: WORKOUT.startDate,
        endDate: WORKOUT.endDate,
        healthKitWorkoutIds: [],
      })
      .expect(401);
  });

  it('syncs workouts and returns history', async () => {
    const token = await register();

    const sync = await http()
      .post('/api/workouts/sync')
      .set(auth(token))
      .send({ workouts: [WORKOUT] })
      .expect(201);
    expect(sync.body.synced).toBe(1);

    const history = await http()
      .get('/api/workouts')
      .set(auth(token))
      .expect(200);
    expect(history.body.total).toBe(1);
    expect(history.body.workouts).toHaveLength(1);
    expect(history.body.workouts[0].type).toBe('running');
    expect(history.body.workouts[0].healthKitWorkoutId).toBe('hk-1');
  });

  it('deletes workouts missing from the reconciliation window', async () => {
    const token = await register();
    await http()
      .post('/api/workouts/sync')
      .set(auth(token))
      .send({ workouts: [WORKOUT] })
      .expect(201);

    const res = await http()
      .delete('/api/workouts/missing')
      .set(auth(token))
      .send({
        startDate: '2026-01-01T00:00:00.000Z',
        endDate: '2026-01-02T00:00:00.000Z',
        healthKitWorkoutIds: [],
      })
      .expect(200);
    expect(res.body.deleted).toBe(1);

    const history = await http()
      .get('/api/workouts')
      .set(auth(token))
      .expect(200);
    expect(history.body.total).toBe(0);
  });

  it('rejects out-of-range metrics', async () => {
    const token = await register();
    await http()
      .post('/api/workouts/sync')
      .set(auth(token))
      .send({ workouts: [{ ...WORKOUT, durationSeconds: 86_401 }] })
      .expect(400);
    await http()
      .post('/api/workouts/sync')
      .set(auth(token))
      .send({ workouts: [{ ...WORKOUT, heartRateAvg: 301 }] })
      .expect(400);
    await http()
      .post('/api/workouts/sync')
      .set(auth(token))
      .send({ workouts: [{ ...WORKOUT, endDate: WORKOUT.startDate }] })
      .expect(400);
  });

  it('rejects an empty batch and a batch over 200 workouts', async () => {
    const token = await register();
    await http()
      .post('/api/workouts/sync')
      .set(auth(token))
      .send({ workouts: [] })
      .expect(400);
    await http()
      .post('/api/workouts/sync')
      .set(auth(token))
      .send({ workouts: manyWorkouts(201) })
      .expect(400);
  });

  it('rejects invalid history and delete queries', async () => {
    const token = await register();
    await http().get('/api/workouts?limit=201').set(auth(token)).expect(400);
    await http()
      .get('/api/workouts?from=2026-02-01&to=2026-01-01')
      .set(auth(token))
      .expect(400);
    await http()
      .delete('/api/workouts/missing')
      .set(auth(token))
      .send({
        startDate: '2026-01-02T00:00:00.000Z',
        endDate: '2026-01-01T00:00:00.000Z',
        healthKitWorkoutIds: [],
      })
      .expect(400);
  });

  it('does not duplicate workouts on re-sync', async () => {
    const token = await register();
    await http()
      .post('/api/workouts/sync')
      .set(auth(token))
      .send({ workouts: [WORKOUT] })
      .expect(201);
    await http()
      .post('/api/workouts/sync')
      .set(auth(token))
      .send({ workouts: [WORKOUT] })
      .expect(201);

    const history = await http()
      .get('/api/workouts')
      .set(auth(token))
      .expect(200);
    expect(history.body.total).toBe(1);
  });

  it('does not read or delete another user data', async () => {
    const tokenA = await register();
    const tokenB = await register();
    await http()
      .post('/api/workouts/sync')
      .set(auth(tokenA))
      .send({ workouts: [WORKOUT] })
      .expect(201);

    const historyB = await http()
      .get('/api/workouts')
      .set(auth(tokenB))
      .expect(200);
    expect(historyB.body.total).toBe(0);

    const deletedB = await http()
      .delete('/api/workouts/missing')
      .set(auth(tokenB))
      .send({
        startDate: '2026-01-01T00:00:00.000Z',
        endDate: '2026-01-03T00:00:00.000Z',
        healthKitWorkoutIds: [],
      })
      .expect(200);
    expect(deletedB.body.deleted).toBe(0);

    const historyA = await http()
      .get('/api/workouts')
      .set(auth(tokenA))
      .expect(200);
    expect(historyA.body.total).toBe(1);
  });
});
