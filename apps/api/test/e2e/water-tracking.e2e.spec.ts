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

describe('water-tracking routes', () => {
  it('rejects an unauthenticated create', async () => {
    await http()
      .post('/api/water-tracking')
      .send({ amountMl: 200 })
      .expect(401);
  });

  it('rejects an out-of-range amount', async () => {
    const token = await register();
    await http()
      .post('/api/water-tracking')
      .set(auth(token))
      .send({ amountMl: 0 })
      .expect(400);
    await http()
      .post('/api/water-tracking')
      .set(auth(token))
      .send({ amountMl: 3001 })
      .expect(400);
  });

  it('creates entries and returns them from today', async () => {
    const token = await register();

    await http()
      .post('/api/water-tracking')
      .set(auth(token))
      .send({ amountMl: 200, date: DATE })
      .expect(201);
    await http()
      .post('/api/water-tracking')
      .set(auth(token))
      .send({ amountMl: 300, date: DATE })
      .expect(201);

    const today = await http()
      .get(`/api/water-tracking/today?date=${DATE}`)
      .set(auth(token))
      .expect(200);
    expect(today.body).toBeArray();
    expect(today.body.length).toBe(2);
  });

  it('requires a date and returns entries for one', async () => {
    const token = await register();

    await http().get('/api/water-tracking').set(auth(token)).expect(400);

    await http()
      .post('/api/water-tracking')
      .set(auth(token))
      .send({ amountMl: 150, date: DATE })
      .expect(201);

    const byDate = await http()
      .get(`/api/water-tracking?date=${DATE}`)
      .set(auth(token))
      .expect(200);
    expect(byDate.body).toBeArray();
    expect(byDate.body.length).toBe(1);
  });

  it('deletes an entry', async () => {
    const token = await register();

    const created = await http()
      .post('/api/water-tracking')
      .set(auth(token))
      .send({ amountMl: 250, date: DATE })
      .expect(201);

    await http()
      .delete(`/api/water-tracking/${created.body.id}`)
      .set(auth(token))
      .expect(200);

    const today = await http()
      .get(`/api/water-tracking/today?date=${DATE}`)
      .set(auth(token))
      .expect(200);
    expect(today.body.length).toBe(0);
  });
});
