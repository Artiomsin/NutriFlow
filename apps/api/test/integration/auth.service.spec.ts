import {
  afterAll,
  beforeAll,
  describe,
  expect,
  it,
  setSystemTime,
} from 'bun:test';
import { randomUUID } from 'node:crypto';
import { ConflictException, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { eq } from 'drizzle-orm';

import { AuthService } from '../../src/auth/auth.service';
import type { AuthPayload } from '../../src/auth/types/auth.types';
import { authSessions } from '../../src/db/schema/authSessions';
import { users } from '../../src/db/schema/users';
import { createAuthTestingModule } from '../utils/auth';
import { createTestDb } from '../utils/db';
import type { TestDb, TestTx } from '../utils/db';

let db: TestDb;
let tx: TestTx;
let rollback: () => Promise<void>;
let service: AuthService;
let jwt: JwtService;

beforeAll(async () => {
  db = createTestDb();
  const opened = await db.openTx();
  tx = opened.tx;
  rollback = opened.rollback;

  const moduleRef = await createAuthTestingModule(tx);
  service = moduleRef.get(AuthService);
  jwt = moduleRef.get(JwtService);
});

afterAll(async () => {
  await rollback();
  await db.close();
});

const uniqueEmail = () => `${randomUUID()}@test.com`;

async function register(
  overrides: {
    email?: string;
    password?: string;
  } = {},
) {
  const email = overrides.email ?? uniqueEmail();
  const tokens = await service.register({
    email,
    password: overrides.password ?? 'secret1',
    firstName: 'Ann',
    lastName: 'Lee',
  });
  return { email, tokens };
}

function decode(token: string): AuthPayload {
  return jwt.decode<AuthPayload>(token);
}

describe('AuthService.register', () => {
  it('creates a user with a hashed password and a session', async () => {
    const { email, tokens } = await register();

    expect(tokens.accessToken).toBeString();
    expect(tokens.refreshToken).toBeString();

    const [user] = await tx.select().from(users).where(eq(users.email, email));
    expect(user).toBeDefined();
    expect(user?.passwordHash).toBeString();
    expect(user?.passwordHash).not.toBe('secret1');
    expect(user?.passwordHash?.startsWith('$2')).toBe(true);

    const sessions = await tx
      .select()
      .from(authSessions)
      .where(eq(authSessions.userId, user!.id));
    expect(sessions).toHaveLength(1);
    expect(sessions[0]?.refreshTokenHash).toHaveLength(64);
  });

  it('rejects a duplicate email', async () => {
    const { email } = await register();

    await expect(
      service.register({
        email,
        password: 'secret1',
        firstName: 'Ann',
        lastName: 'Lee',
      }),
    ).rejects.toBeInstanceOf(ConflictException);
  });
});

describe('AuthService.login', () => {
  it('returns tokens for valid credentials', async () => {
    const { email } = await register({ password: 'secret1' });

    const tokens = await service.login({ email, password: 'secret1' });

    expect(tokens.accessToken).toBeString();
    expect(tokens.refreshToken).toBeString();
  });

  it('rejects an invalid password', async () => {
    const { email } = await register({ password: 'secret1' });

    await expect(
      service.login({ email, password: 'wrong-password' }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('rejects an unknown email', async () => {
    await expect(
      service.login({ email: uniqueEmail(), password: 'secret1' }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });
});

describe('AuthService.refresh', () => {
  it('rotates the session on a valid refresh token', async () => {
    // Future base time keeps session.expiresAt > createdAt (DB uses real now).
    const t0 = new Date(Date.now() + 5_000);
    setSystemTime(t0);
    try {
      const { tokens } = await register();
      const payload = decode(tokens.refreshToken);

      setSystemTime(new Date(t0.getTime() + 2_000));
      const next = await service.refresh(tokens.refreshToken);
      expect(next.refreshToken).not.toBe(tokens.refreshToken);

      const [session] = await tx
        .select()
        .from(authSessions)
        .where(eq(authSessions.sessionId, payload.sessionId));

      expect(session?.refreshTokenHash).toHaveLength(64);
      expect(session?.previousRefreshTokenHash).toHaveLength(64);
      expect(session?.previousValidUntil).toBeInstanceOf(Date);
    } finally {
      setSystemTime();
    }
  });

  it('rejects a malformed token', async () => {
    await expect(service.refresh('not-a-jwt')).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });

  it('rejects a replayed token inside the grace window without revoking', async () => {
    // Future base time keeps session.expiresAt > createdAt (DB uses real now).
    const t0 = new Date(Date.now() + 5_000);
    setSystemTime(t0);
    try {
      const { tokens } = await register();
      const payload = decode(tokens.refreshToken);

      setSystemTime(new Date(t0.getTime() + 2_000));
      const next = await service.refresh(tokens.refreshToken);
      expect(next.refreshToken).not.toBe(tokens.refreshToken);

      await expect(service.refresh(tokens.refreshToken)).rejects.toBeInstanceOf(
        UnauthorizedException,
      );

      const [session] = await tx
        .select()
        .from(authSessions)
        .where(eq(authSessions.sessionId, payload.sessionId));
      expect(session?.revokedAt).toBeNull();
    } finally {
      setSystemTime();
    }
  });

  it('revokes the session on a replay outside the grace window', async () => {
    // Future base time keeps session.expiresAt > createdAt (DB uses real now).
    const t0 = new Date(Date.now() + 5_000);
    setSystemTime(t0);
    try {
      const { tokens } = await register();
      const payload = decode(tokens.refreshToken);

      setSystemTime(new Date(t0.getTime() + 2_000));
      await service.refresh(tokens.refreshToken);

      setSystemTime(new Date(t0.getTime() + 200_000));
      await expect(service.refresh(tokens.refreshToken)).rejects.toBeInstanceOf(
        UnauthorizedException,
      );

      const [session] = await tx
        .select()
        .from(authSessions)
        .where(eq(authSessions.sessionId, payload.sessionId));
      expect(session?.revokedAt).not.toBeNull();
    } finally {
      setSystemTime();
    }
  });
});

describe('AuthService.logout', () => {
  it('revokes the current session', async () => {
    const { tokens } = await register();
    const payload = decode(tokens.accessToken);

    await service.logout(payload.userId, payload.sessionId);

    expect(
      await service.isSessionAlive(payload.userId, payload.sessionId),
    ).toBe(false);
  });
});

describe('AuthService.logoutAll', () => {
  it('revokes every session of the user', async () => {
    const { email, tokens } = await register();
    const first = decode(tokens.accessToken);

    const second = await service.login({ email, password: 'secret1' });
    const secondPayload = decode(second.accessToken);

    await service.logoutAll(first.userId);

    expect(await service.isSessionAlive(first.userId, first.sessionId)).toBe(
      false,
    );
    expect(
      await service.isSessionAlive(
        secondPayload.userId,
        secondPayload.sessionId,
      ),
    ).toBe(false);
  });
});

describe('AuthService.isSessionAlive', () => {
  it('is true for an active session', async () => {
    const { tokens } = await register();
    const payload = decode(tokens.accessToken);

    expect(
      await service.isSessionAlive(payload.userId, payload.sessionId),
    ).toBe(true);
  });

  it('is false for an expired session', async () => {
    const { tokens } = await register();
    const payload = decode(tokens.accessToken);

    const past = Date.now() - 3_600_000;
    await tx
      .update(authSessions)
      .set({
        createdAt: new Date(past),
        expiresAt: new Date(past + 1_800_000),
      })
      .where(eq(authSessions.sessionId, payload.sessionId));

    expect(
      await service.isSessionAlive(payload.userId, payload.sessionId),
    ).toBe(false);
  });
});
