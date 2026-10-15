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

const profileInput = () => ({
  weight: 80,
  height: 180,
  age: 30,
  gender: 'male' as const,
  goal: 'maintain' as const,
  activityLevel: 'medium' as const,
  timeZone: 'UTC',
});

describe('profiles routes', () => {
  it('rejects an unauthenticated read', async () => {
    await http().get('/api/profiles/me').expect(401);
  });

  it('returns 404 before a profile exists', async () => {
    const token = await register();
    await http().get('/api/profiles/me').set(auth(token)).expect(404);
  });

  it('rejects an out-of-range body in the filter error shape', async () => {
    const token = await register();
    const res = await http()
      .post('/api/profiles')
      .set(auth(token))
      .send({ ...profileInput(), weight: 10 })
      .expect(400);

    expect(res.body.statusCode).toBe(400);
    expect(res.body.requestId).toBeString();
    expect(res.body.error.fieldErrors.weight).toBeArray();
  });

  it('creates a profile and reads it back idempotently', async () => {
    const token = await register();
    const body = profileInput();

    const created = await http()
      .post('/api/profiles')
      .set(auth(token))
      .send(body)
      .expect(201);

    const again = await http()
      .post('/api/profiles')
      .set(auth(token))
      .send(body)
      .expect(201);
    expect(again.body.id).toBe(created.body.id);

    const me = await http()
      .get('/api/profiles/me')
      .set(auth(token))
      .expect(200);
    expect(me.body.userId).toBe(created.body.userId);
    expect(me.body.goal).toBe('maintain');
  });

  it('updates the profile', async () => {
    const token = await register();
    await http()
      .post('/api/profiles')
      .set(auth(token))
      .send(profileInput())
      .expect(201);

    const updated = await http()
      .put('/api/profiles/me')
      .set(auth(token))
      .send({ goal: 'lose', age: 41 })
      .expect(200);
    expect(updated.body.goal).toBe('lose');
    expect(updated.body.age).toBe(41);
  });

  it('updates the time zone and rejects an invalid one', async () => {
    const token = await register();
    await http()
      .post('/api/profiles')
      .set(auth(token))
      .send(profileInput())
      .expect(201);

    const updated = await http()
      .put('/api/profiles/me/time-zone')
      .set(auth(token))
      .send({ timeZone: 'Europe/Paris' })
      .expect(200);
    expect(updated.body.timeZone).toBe('Europe/Paris');

    await http()
      .put('/api/profiles/me/time-zone')
      .set(auth(token))
      .send({ timeZone: 'Mars/Phobos' })
      .expect(400);
  });

  it('deletes the profile', async () => {
    const token = await register();
    await http()
      .post('/api/profiles')
      .set(auth(token))
      .send(profileInput())
      .expect(201);

    await http().delete('/api/profiles/me').set(auth(token)).expect(200);
    await http().get('/api/profiles/me').set(auth(token)).expect(404);
  });
});
