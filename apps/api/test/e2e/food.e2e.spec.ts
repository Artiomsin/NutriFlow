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
const realFetch = globalThis.fetch;

beforeAll(async () => {
  // Keep the catalog search offline: USDA is only reached when local rows are
  // few, and the e2e suite must not depend on the network.
  globalThis.fetch = (async () =>
    ({
      ok: true,
      status: 200,
      json: async () => ({ foods: [] }),
    }) as unknown as Response) as unknown as typeof fetch;

  db = createTestDb();
  const opened = await db.openTx();
  rollback = opened.rollback;
  app = await createE2eApp(opened.tx);
});

afterAll(async () => {
  await app.close();
  await rollback();
  await db.close();
  globalThis.fetch = realFetch;
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

describe('food-entry routes', () => {
  it('rejects an unauthenticated create', async () => {
    await http()
      .post('/api/food-entry')
      .send({ name: 'Test', calories: 100 })
      .expect(401);
  });

  it('rejects an invalid body in the filter error shape', async () => {
    const token = await register();
    const res = await http()
      .post('/api/food-entry')
      .set(auth(token))
      .send({ calories: 100 })
      .expect(400);
    expect(res.body.statusCode).toBe(400);
    expect(res.body.requestId).toBeString();
    expect(res.body.error.fieldErrors.name).toBeArray();
  });

  it('creates an entry and returns it from today', async () => {
    const token = await register();
    const name = `e2e-food-${randomUUID()}`;

    const created = await http()
      .post('/api/food-entry')
      .set(auth(token))
      .send({
        name,
        calories: 250,
        protein: 10,
        fat: 5,
        carbs: 20,
        grams: 100,
        date: DATE,
      })
      .expect(201);
    expect(created.body.name).toBe(name);

    const today = await http()
      .get(`/api/food-entry/today?date=${DATE}`)
      .set(auth(token))
      .expect(200);
    expect(today.body).toBeArray();
    expect(
      today.body.some((e: { id: string }) => e.id === created.body.id),
    ).toBe(true);
  });

  it('updates an entry and rejects a non-uuid id', async () => {
    const token = await register();
    const name = `e2e-food-${randomUUID()}`;

    const created = await http()
      .post('/api/food-entry')
      .set(auth(token))
      .send({ name, calories: 200, grams: 100, date: DATE })
      .expect(201);

    const patched = await http()
      .patch(`/api/food-entry/${created.body.id}`)
      .set(auth(token))
      .send({ calories: 300 })
      .expect(200);
    expect(patched.body.id).toBe(created.body.id);

    await http()
      .patch('/api/food-entry/not-a-uuid')
      .set(auth(token))
      .send({ calories: 300 })
      .expect(400);
  });

  it('deletes an entry and returns an empty day', async () => {
    const token = await register();
    const name = `e2e-food-${randomUUID()}`;

    const created = await http()
      .post('/api/food-entry')
      .set(auth(token))
      .send({ name, calories: 150, date: DATE })
      .expect(201);

    await http()
      .delete(`/api/food-entry/${created.body.id}`)
      .set(auth(token))
      .expect(200);

    const today = await http()
      .get(`/api/food-entry/today?date=${DATE}`)
      .set(auth(token))
      .expect(200);
    expect(today.body).toBeArray();
    expect(today.body.length).toBe(0);
  });
});

describe('food catalog routes', () => {
  it('requires a query and returns results for one', async () => {
    const token = await register();

    await http().get('/api/foods/search').set(auth(token)).expect(400);

    const res = await http()
      .get('/api/foods/search?q=chicken')
      .set(auth(token))
      .expect(200);
    expect(res.body.foods).toBeArray();
  });

  it('rejects a non-uuid food id', async () => {
    const token = await register();
    await http().get('/api/foods/not-a-uuid').set(auth(token)).expect(400);
  });
});

describe('food upload route', () => {
  it('rejects a missing file', async () => {
    const token = await register();
    await http().post('/api/food/upload').set(auth(token)).expect(400);
  });

  it('rejects an unsupported mime type', async () => {
    const token = await register();
    await http()
      .post('/api/food/upload')
      .set(auth(token))
      .attach('file', Buffer.from('not an image'), {
        filename: 'note.txt',
        contentType: 'text/plain',
      })
      .expect(400);
  });
});
