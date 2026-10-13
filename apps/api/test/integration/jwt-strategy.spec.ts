import { afterAll, beforeAll, describe, expect, it } from 'bun:test';
import { randomUUID } from 'node:crypto';
import { UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';

import { AuthService } from '../../src/auth/auth.service';
import { JwtStrategy } from '../../src/auth/jwt.strategy';
import type { AuthPayload } from '../../src/auth/types/auth.types';
import { createAuthTestingModule } from '../utils/auth';
import { createTestDb } from '../utils/db';
import type { TestDb } from '../utils/db';

let db: TestDb;
let rollback: () => Promise<void>;
let service: AuthService;
let strategy: JwtStrategy;
let jwt: JwtService;

beforeAll(async () => {
  db = createTestDb();
  const opened = await db.openTx();
  rollback = opened.rollback;

  const moduleRef = await createAuthTestingModule(opened.tx);
  service = moduleRef.get(AuthService);
  strategy = moduleRef.get(JwtStrategy);
  jwt = moduleRef.get(JwtService);
});

afterAll(async () => {
  await rollback();
  await db.close();
});

async function registerAndDecode(): Promise<AuthPayload> {
  const tokens = await service.register({
    email: `${randomUUID()}@test.com`,
    password: 'secret1',
    firstName: 'Ann',
    lastName: 'Lee',
  });
  return jwt.decode<AuthPayload>(tokens.accessToken);
}

describe('JwtStrategy.validate', () => {
  it('returns the payload for a live session', async () => {
    const payload = await registerAndDecode();

    expect(strategy.validate(payload)).resolves.toEqual(payload);
  });

  it('throws when the session has been revoked', async () => {
    const payload = await registerAndDecode();
    await service.logout(payload.userId, payload.sessionId);

    expect(strategy.validate(payload)).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });
});
