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
const DATE = '2026-10-06';

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

describe('daily-summary routes', () => {
  it('rejects unauthenticated reads', async () => {
    await http().get('/api/daily-summary/today').expect(401);
    await http().get('/api/daily-summary/dashboard').expect(401);
    await http().get('/api/daily-summary/range').expect(401);
  });

  it('returns today and an explicit date', async () => {
    const token = await register();

    await http().get('/api/daily-summary/today').set(auth(token)).expect(200);
    await http()
      .get(`/api/daily-summary?date=${DATE}`)
      .set(auth(token))
      .expect(200);
  });

  it('aggregates food and water into the dashboard', async () => {
    const token = await register();

    await http()
      .post('/api/food-entry')
      .set(auth(token))
      .send({
        name: `e2e-summary-${randomUUID()}`,
        calories: 250,
        protein: 10,
        fat: 5,
        carbs: 20,
        grams: 100,
        date: DATE,
      })
      .expect(201);
    await http()
      .post('/api/water-tracking')
      .set(auth(token))
      .send({ amountMl: 500, date: DATE })
      .expect(201);

    const res = await http()
      .get(`/api/daily-summary/dashboard?date=${DATE}`)
      .set(auth(token))
      .expect(200);

    expect(res.body.dailySummary.totalCalories).toBe(250);
    expect(res.body.dailySummary.totalWaterMl).toBe(500);
    expect(res.body.foodEntries.length).toBe(1);
    expect(res.body.waterEntries.length).toBe(1);
  });

  it('validates the range query', async () => {
    const token = await register();

    await http().get('/api/daily-summary/range').set(auth(token)).expect(400);
    await http()
      .get(`/api/daily-summary/range?from=${DATE}&to=2026-10-01`)
      .set(auth(token))
      .expect(400);
  });
});
