import { afterAll, beforeAll, describe, expect, it } from 'bun:test';
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

describe('rate limiting', () => {
  it('blocks the request after the configured auth limit', async () => {
    const http = () =>
      request(app.getHttpServer())
        .post('/api/auth/login')
        .send({ email: 'invalid', password: 'short' });

    await http().expect(400);
    await http().expect(400);
    const blocked = await http().expect(429);

    expect(blocked.headers['retry-after']).toBeString();
  });

  it('does not limit Render health checks', async () => {
    const response = await request(app.getHttpServer())
      .get('/api/health/ready')
      .expect(200);

    expect(response.headers['x-ratelimit-limit']).toBeUndefined();
  });
});
