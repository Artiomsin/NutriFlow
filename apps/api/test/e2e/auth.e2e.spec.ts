import {
  afterAll,
  beforeAll,
  describe,
  expect,
  it,
  setSystemTime,
} from 'bun:test';
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
const uniqueEmail = () => `${randomUUID()}@test.com`;

const credentials = (email: string) => ({
  email,
  password: 'secret1',
  firstName: 'Ann',
  lastName: 'Lee',
});

async function register(email = uniqueEmail()) {
  const res = await http()
    .post('/api/auth/register')
    .send(credentials(email))
    .expect(201);
  return {
    email,
    tokens: res.body as { accessToken: string; refreshToken: string },
  };
}

describe('POST /api/auth/register', () => {
  it('creates an account and returns tokens', async () => {
    const res = await http()
      .post('/api/auth/register')
      .send(credentials(uniqueEmail()))
      .expect(201);
    expect(res.body.accessToken).toBeString();
    expect(res.body.refreshToken).toBeString();
  });

  it('rejects an invalid email in the filter error shape', async () => {
    const res = await http()
      .post('/api/auth/register')
      .send({ ...credentials(uniqueEmail()), email: 'nope' })
      .expect(400);
    expect(res.body.statusCode).toBe(400);
    expect(res.body.requestId).toBeString();
    expect(res.body.error.fieldErrors.email).toBeArray();
  });

  it('rejects a short password', async () => {
    await http()
      .post('/api/auth/register')
      .send({ ...credentials(uniqueEmail()), password: '123' })
      .expect(400);
  });

  it('rejects a duplicate email', async () => {
    const { email } = await register();
    await http()
      .post('/api/auth/register')
      .send(credentials(email))
      .expect(409);
  });
});

describe('POST /api/auth/login', () => {
  it('returns tokens for valid credentials', async () => {
    const { email } = await register();
    const res = await http()
      .post('/api/auth/login')
      .send({ email, password: 'secret1' })
      .expect(201);
    expect(res.body.accessToken).toBeString();
  });

  it('rejects a wrong password', async () => {
    const { email } = await register();
    await http()
      .post('/api/auth/login')
      .send({ email, password: 'wrong-password' })
      .expect(401);
  });

  it('rejects an unknown email', async () => {
    await http()
      .post('/api/auth/login')
      .send({ email: uniqueEmail(), password: 'secret1' })
      .expect(401);
  });
});

describe('POST /api/auth/refresh', () => {
  it('rotates the refresh token', async () => {
    // Future base keeps session.expiresAt > createdAt (DB uses real now);
    // +2s crosses a JWT `iat` second boundary so the token actually changes.
    const t0 = new Date(Date.now() + 5_000);
    setSystemTime(t0);
    try {
      const { tokens } = await register();

      setSystemTime(new Date(t0.getTime() + 2_000));
      const res = await http()
        .post('/api/auth/refresh')
        .send({ refreshToken: tokens.refreshToken })
        .expect(201);
      expect(res.body.refreshToken).not.toBe(tokens.refreshToken);
    } finally {
      setSystemTime();
    }
  });

  it('rejects a malformed token', async () => {
    await http()
      .post('/api/auth/refresh')
      .send({ refreshToken: 'not-a-jwt' })
      .expect(401);
  });
});

describe('auth guard + logout', () => {
  it('rejects logout without a token', async () => {
    await http().post('/api/auth/logout').expect(401);
  });

  it('revokes the session and rejects the reused token', async () => {
    const { tokens } = await register();
    await http()
      .post('/api/auth/logout')
      .set('Authorization', `Bearer ${tokens.accessToken}`)
      .expect(201);
    await http()
      .post('/api/auth/logout')
      .set('Authorization', `Bearer ${tokens.accessToken}`)
      .expect(401);
  });

  it('revokes every session on logout-all', async () => {
    const { email, tokens } = await register();
    const second = await http()
      .post('/api/auth/login')
      .send({ email, password: 'secret1' })
      .expect(201);

    await http()
      .post('/api/auth/logout-all')
      .set('Authorization', `Bearer ${tokens.accessToken}`)
      .expect(201);

    await http()
      .post('/api/auth/logout')
      .set('Authorization', `Bearer ${tokens.accessToken}`)
      .expect(401);
    await http()
      .post('/api/auth/logout')
      .set('Authorization', `Bearer ${second.body.accessToken}`)
      .expect(401);
  });
});

describe('routing', () => {
  it('does not expose routes without the api prefix', async () => {
    await http()
      .post('/auth/register')
      .send(credentials(uniqueEmail()))
      .expect(404);
  });
});
