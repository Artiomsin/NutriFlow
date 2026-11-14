import { afterAll, beforeAll, describe, expect, it } from 'bun:test';
import { randomUUID } from 'node:crypto';
import type { INestApplication } from '@nestjs/common';
import request from 'supertest';

import { createE2eApp } from '../utils/e2e';
import { createTestDb } from '../utils/db';
import type { TestDb } from '../utils/db';

const describeLive =
  process.env.RUN_LIVE_BARCODE_TESTS === 'true' ? describe : describe.skip;

// A network-dependent test: skipped unless explicitly enabled by its script.
describeLive('live barcode lookup', () => {
  let db: TestDb;
  let rollback: (() => Promise<void>) | undefined;
  let app: INestApplication | undefined;

  const http = () => request(app!.getHttpServer());

  beforeAll(async () => {
    db = createTestDb();
    const opened = await db.openTx();
    rollback = opened.rollback;
    app = await createE2eApp(opened.tx);
  });

  afterAll(async () => {
    await app?.close();
    await rollback?.();
    await db?.close();
  });

  it('looks up a product from Open Food Facts through the public API', async () => {
    const registration = await http()
      .post('/api/auth/register')
      .send({
        email: `${randomUUID()}@test.com`,
        password: 'secret1',
        firstName: 'Live',
        lastName: 'Barcode',
      })
      .expect(201);
    const token = (registration.body as { accessToken: string }).accessToken;

    // Nutella's GTIN-13, a long-lived public Open Food Facts product.
    const response = await http()
      .get('/api/foods/barcode/3017620422003')
      .set({ Authorization: `Bearer ${token}` })
      .expect(200);

    expect(response.body).toMatchObject({
      source: 'off',
      provider: 'open-food-facts',
      barcode: '3017620422003',
    });
    expect(response.body.name).toBeString();
    expect(response.body.caloriesPer100g).toBeGreaterThan(0);
  }, 20_000);
});
