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

const NIGHT = {
  startDate: '2026-01-01T22:00:00.000Z',
  endDate: '2026-01-02T06:00:00.000Z',
  localDate: '2026-01-02',
  asleepSeconds: 25_000,
  efficiency: 90,
};

function manyNights(count: number) {
  return Array.from({ length: count }, (_, i) => {
    const start = new Date(Date.UTC(2026, 0, 1, 0, i % 60));
    return {
      startDate: start.toISOString(),
      endDate: new Date(start.getTime() + 3_600_000).toISOString(),
      localDate: '2026-01-01',
    };
  });
}

describe('sleep routes', () => {
  it('rejects unauthenticated requests', async () => {
    await http()
      .post('/api/sleep/sync')
      .send({ nights: [NIGHT] })
      .expect(401);
    await http().get('/api/sleep').expect(401);
    await http()
      .delete('/api/sleep/missing')
      .send({
        startDate: NIGHT.startDate,
        endDate: NIGHT.endDate,
        keptStartDates: [],
      })
      .expect(401);
  });

  it('syncs sleep and returns history', async () => {
    const token = await register();

    const sync = await http()
      .post('/api/sleep/sync')
      .set(auth(token))
      .send({ nights: [NIGHT] })
      .expect(201);
    expect(sync.body.synced).toBe(1);

    const history = await http().get('/api/sleep').set(auth(token)).expect(200);
    expect(history.body.total).toBe(1);
    expect(history.body.nights).toHaveLength(1);
    expect(history.body.nights[0].asleepSeconds).toBe(25_000);
    expect(history.body.nights[0].localDate).toBe('2026-01-02');
  });

  it('deletes nights missing from the reconciliation window', async () => {
    const token = await register();
    await http()
      .post('/api/sleep/sync')
      .set(auth(token))
      .send({ nights: [NIGHT] })
      .expect(201);

    const res = await http()
      .delete('/api/sleep/missing')
      .set(auth(token))
      .send({
        startDate: '2026-01-01T00:00:00.000Z',
        endDate: '2026-01-03T00:00:00.000Z',
        keptStartDates: [],
      })
      .expect(200);
    expect(res.body.deleted).toBe(1);

    const history = await http().get('/api/sleep').set(auth(token)).expect(200);
    expect(history.body.total).toBe(0);
  });

  it('rejects out-of-range metrics', async () => {
    const token = await register();
    await http()
      .post('/api/sleep/sync')
      .set(auth(token))
      .send({ nights: [{ ...NIGHT, timeInBedSeconds: 86_401 }] })
      .expect(400);
    await http()
      .post('/api/sleep/sync')
      .set(auth(token))
      .send({ nights: [{ ...NIGHT, efficiency: 101 }] })
      .expect(400);
    await http()
      .post('/api/sleep/sync')
      .set(auth(token))
      .send({ nights: [{ ...NIGHT, endDate: NIGHT.startDate }] })
      .expect(400);
  });

  it('rejects an empty batch and a batch over 50 nights', async () => {
    const token = await register();
    await http()
      .post('/api/sleep/sync')
      .set(auth(token))
      .send({ nights: [] })
      .expect(400);
    await http()
      .post('/api/sleep/sync')
      .set(auth(token))
      .send({ nights: manyNights(51) })
      .expect(400);
  });

  it('rejects invalid history and delete queries', async () => {
    const token = await register();
    await http().get('/api/sleep?limit=201').set(auth(token)).expect(400);
    await http()
      .get('/api/sleep?from=2026-02-01&to=2026-01-01')
      .set(auth(token))
      .expect(400);
    await http()
      .delete('/api/sleep/missing')
      .set(auth(token))
      .send({
        startDate: '2026-01-02T00:00:00.000Z',
        endDate: '2026-01-01T00:00:00.000Z',
        keptStartDates: [],
      })
      .expect(400);
  });

  it('does not duplicate nights on re-sync', async () => {
    const token = await register();
    await http()
      .post('/api/sleep/sync')
      .set(auth(token))
      .send({ nights: [NIGHT] })
      .expect(201);
    await http()
      .post('/api/sleep/sync')
      .set(auth(token))
      .send({ nights: [NIGHT] })
      .expect(201);

    const history = await http().get('/api/sleep').set(auth(token)).expect(200);
    expect(history.body.total).toBe(1);
  });

  it('does not read or delete another user data', async () => {
    const tokenA = await register();
    const tokenB = await register();
    await http()
      .post('/api/sleep/sync')
      .set(auth(tokenA))
      .send({ nights: [NIGHT] })
      .expect(201);

    const historyB = await http()
      .get('/api/sleep')
      .set(auth(tokenB))
      .expect(200);
    expect(historyB.body.total).toBe(0);

    const deletedB = await http()
      .delete('/api/sleep/missing')
      .set(auth(tokenB))
      .send({
        startDate: '2026-01-01T00:00:00.000Z',
        endDate: '2026-01-03T00:00:00.000Z',
        keptStartDates: [],
      })
      .expect(200);
    expect(deletedB.body.deleted).toBe(0);

    const historyA = await http()
      .get('/api/sleep')
      .set(auth(tokenA))
      .expect(200);
    expect(historyA.body.total).toBe(1);
  });
});
