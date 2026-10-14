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
const UUID = '11111111-1111-4111-8111-111111111111';

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

async function createProfile(token: string) {
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

describe('goals routes', () => {
  it('rejects unauthenticated reads', async () => {
    await http().get('/api/goals').expect(401);
  });

  it('returns 404 before goals exist', async () => {
    const token = await register();
    await http().get('/api/goals').set(auth(token)).expect(404);
  });

  it('creates goals via PATCH and returns history', async () => {
    const token = await register();

    const patched = await http()
      .patch('/api/goals')
      .set(auth(token))
      .send({ dailyCaloriesGoal: 2100 })
      .expect(200);
    expect(patched.body.source).toBe('user');
    expect(patched.body.dailyCaloriesGoal).toBe(2100);

    const fetched = await http().get('/api/goals').set(auth(token)).expect(200);
    expect(fetched.body.dailyCaloriesGoal).toBe(2100);

    const history = await http()
      .get('/api/goals/history')
      .set(auth(token))
      .expect(200);
    expect(history.body).toBeArray();
    expect(history.body.length).toBeGreaterThan(0);
  });

  it('rejects an invalid goals body', async () => {
    const token = await register();
    await http()
      .patch('/api/goals')
      .set(auth(token))
      .send({ dailyCaloriesGoal: -1 })
      .expect(400);
  });

  it('requires a profile to calculate', async () => {
    const token = await register();
    await http().post('/api/goals/calculate').set(auth(token)).expect(404);
  });

  it('calculates goals from the profile', async () => {
    const token = await register();
    await createProfile(token);

    const res = await http()
      .post('/api/goals/calculate')
      .set(auth(token))
      .expect(201);
    expect(res.body.source).toBe('initial');
    expect(res.body.dailyCaloriesGoal).toBe(2759);
  });

  it('resets manual goals back to automatic', async () => {
    const token = await register();
    await createProfile(token);
    await http()
      .patch('/api/goals')
      .set(auth(token))
      .send({ dailyCaloriesGoal: 3000 })
      .expect(200);

    const res = await http()
      .post('/api/goals/reset-to-automatic')
      .set(auth(token))
      .expect(201);
    expect(res.body.source).toBe('initial');
    expect(res.body.dailyCaloriesGoal).toBe(2759);
  });

  it('reports personalization state and a fresh run as not_due', async () => {
    const token = await register();

    const personalized = await http()
      .post('/api/goals/personalize')
      .set(auth(token))
      .expect(201);
    expect(personalized.body.status).toBe('not_due');

    const state = await http()
      .get('/api/goals/personalization')
      .set(auth(token))
      .expect(200);
    expect(state.body.personalizationDue).toBeBoolean();
    expect(state.body.pending).toBeNull();
  });

  it('validates recommendation ids', async () => {
    const token = await register();

    await http()
      .post('/api/goals/personalization/not-a-uuid/accept')
      .set(auth(token))
      .expect(400);
    await http()
      .post(`/api/goals/personalization/${UUID}/accept`)
      .set(auth(token))
      .expect(404);

    await http()
      .post('/api/goals/personalization/not-a-uuid/dismiss')
      .set(auth(token))
      .expect(400);
    await http()
      .post(`/api/goals/personalization/${UUID}/dismiss`)
      .set(auth(token))
      .expect(404);
  });
});
