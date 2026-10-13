import { afterAll, beforeAll, describe, expect, it, spyOn } from 'bun:test';
import { randomUUID } from 'node:crypto';
import { UnauthorizedException } from '@nestjs/common';
import appleSignin from 'apple-signin-auth';
import { eq } from 'drizzle-orm';

import { AuthService } from '../../src/auth/auth.service';
import { authSessions } from '../../src/db/schema/authSessions';
import { users } from '../../src/db/schema/users';
import { createAuthTestingModule } from '../utils/auth';
import { createTestDb } from '../utils/db';
import type { TestDb, TestTx } from '../utils/db';

let db: TestDb;
let tx: TestTx;
let rollback: () => Promise<void>;
let service: AuthService;

beforeAll(async () => {
  db = createTestDb();
  const opened = await db.openTx();
  tx = opened.tx;
  rollback = opened.rollback;

  const moduleRef = await createAuthTestingModule(tx);
  service = moduleRef.get(AuthService);
});

afterAll(async () => {
  await rollback();
  await db.close();
});

type GooglePayload = {
  email?: string;
  email_verified?: boolean;
  sub?: string;
  given_name?: string;
  family_name?: string;
  picture?: string;
};

function fakeGoogle(payload: GooglePayload | undefined) {
  (service as unknown as { googleClient: unknown }).googleClient = {
    verifyIdToken: async () => ({ getPayload: () => payload }),
  };
}

describe('AuthService.googleLogin', () => {
  it('creates a user and a session for a verified Google account', async () => {
    const email = `${randomUUID()}@test.com`;
    const sub = randomUUID();
    fakeGoogle({
      email,
      email_verified: true,
      sub,
      given_name: 'G',
      family_name: 'U',
      picture: 'https://x/y.png',
    });

    const tokens = await service.googleLogin({ idToken: 'ignored' });
    expect(tokens.accessToken).toBeString();

    const [user] = await tx.select().from(users).where(eq(users.googleId, sub));
    expect(user?.email).toBe(email);
    expect(user?.avatarUrl).toBe('https://x/y.png');

    const sessions = await tx
      .select()
      .from(authSessions)
      .where(eq(authSessions.userId, user!.id));
    expect(sessions).toHaveLength(1);
  });

  it('links an existing user matched by email', async () => {
    const email = `${randomUUID()}@test.com`;
    await service.register({
      email,
      password: 'secret1',
      firstName: 'A',
      lastName: 'B',
    });
    const sub = randomUUID();
    fakeGoogle({ email, email_verified: true, sub });

    const tokens = await service.googleLogin({ idToken: 'ignored' });
    expect(tokens.accessToken).toBeString();

    const [user] = await tx.select().from(users).where(eq(users.email, email));
    expect(user?.googleId).toBe(sub);
  });

  it('rejects an unverified Google account', async () => {
    fakeGoogle({
      email: `${randomUUID()}@test.com`,
      email_verified: false,
      sub: randomUUID(),
    });

    expect(service.googleLogin({ idToken: 'ignored' })).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });
});

describe('AuthService.appleLogin', () => {
  it('creates a user and a session for a valid Apple token', async () => {
    const sub = randomUUID();
    const email = `${randomUUID()}@test.com`;
    const spy = spyOn(appleSignin, 'verifyIdToken').mockResolvedValue({
      sub,
      email,
    } as never);

    try {
      const tokens = await service.appleLogin({ identityToken: 'ignored' });
      expect(tokens.accessToken).toBeString();

      const [user] = await tx
        .select()
        .from(users)
        .where(eq(users.appleId, sub));
      expect(user?.email).toBe(email);
    } finally {
      spy.mockRestore();
    }
  });

  it('rejects an invalid Apple token', async () => {
    const spy = spyOn(appleSignin, 'verifyIdToken').mockRejectedValue(
      new Error('invalid') as never,
    );

    try {
      expect(
        service.appleLogin({ identityToken: 'bad' }),
      ).rejects.toBeInstanceOf(UnauthorizedException);
    } finally {
      spy.mockRestore();
    }
  });
});
