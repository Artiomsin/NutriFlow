import { Injectable, UnauthorizedException, ConflictException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { randomUUID, createHash } from 'crypto';
import { OAuth2Client } from 'google-auth-library';
import appleSignin from 'apple-signin-auth';

import { db } from '../db/db';
import { users } from '../db/schema/users';
import { authSessions } from '../db/schema/authSessions';
import { and, eq, gt, isNull, or } from 'drizzle-orm';

import type { AuthPayload } from './types/auth.types';
import { env } from '../config/env';

@Injectable()
export class AuthService {
  private googleClient = new OAuth2Client(env.GOOGLE_CLIENT_ID);

  constructor(private jwtService: JwtService) {}

  async register(data: {
    email: string;
    password: string;
    firstName: string;
    lastName: string;
  }) {
    const existing = await db
      .select()
      .from(users)
      .where(eq(users.email, data.email))
      .limit(1)
      .then((r) => r[0]);

    if (existing) {
      throw new ConflictException('Email already registered');
    }

    const hash = await bcrypt.hash(data.password, 10);
  
    let user: Array<typeof users.$inferSelect>;
    try {
      user = await db
        .insert(users)
        .values({
          email: data.email,
          passwordHash: hash,
          firstName: data.firstName,
          lastName: data.lastName,
        })
        .returning();
    } catch (error) {
      if (this.isUniqueViolation(error)) {
        throw new ConflictException('Email already registered');
      }
      throw error;
    }
  
    const createdUser = user[0];
  
    if (!createdUser) {
      throw new Error('User creation failed');
    }
  
    const sessionId = randomUUID();
  
    const tokens = this.generateTokens(createdUser.id, sessionId);
  
    await this.createSession(createdUser.id, sessionId, tokens.refreshToken);
  
    return tokens;
  }

 
  async login(data: { email: string; password: string }) {
    const user = await db
      .select()
      .from(users)
      .where(eq(users.email, data.email))
      .limit(1)
      .then((r) => r[0]);

    if (!user) throw new UnauthorizedException();

    const valid = await bcrypt.compare(data.password, user.passwordHash ?? '');

    if (!valid) throw new UnauthorizedException();

    const sessionId = randomUUID();

    const tokens = this.generateTokens(user.id, sessionId);

    await this.createSession(user.id, sessionId, tokens.refreshToken);

    return tokens;
  }

  async googleLogin(data: { idToken: string }) {
    const ticket = await this.googleClient.verifyIdToken({
      idToken: data.idToken,
      audience: env.GOOGLE_CLIENT_ID,
    });

    const payload = ticket.getPayload();

    if (!payload?.email || payload.email_verified !== true) {
      throw new UnauthorizedException('Google account email is not verified');
    }

    const googleId = payload.sub;
    const email = payload.email;
    const firstName = payload.given_name ?? '';
    const lastName = payload.family_name ?? '';
    const avatarUrl = payload.picture ?? null;

    const existing = await db
      .select()
      .from(users)
      .where(or(eq(users.googleId, googleId), eq(users.email, email)))
      .limit(1)
      .then((r) => r[0]);

    let userId: string;

    if (existing) {
      userId = existing.id;
      await db
        .update(users)
        .set({ googleId, firstName, lastName, avatarUrl })
        .where(eq(users.id, existing.id));
    } else {
      const created = await db
        .insert(users)
        .values({ email, googleId, firstName, lastName, avatarUrl })
        .returning();
      const createdUser = created[0];
      if (!createdUser) throw new Error('Failed to create user');
      userId = createdUser.id;
    }

    const sessionId = randomUUID();
    const tokens = this.generateTokens(userId, sessionId);
    await this.createSession(userId, sessionId, tokens.refreshToken);

    return tokens;
  }

  async appleLogin(data: {
    identityToken: string;
    firstName?: string;
    lastName?: string;
    nonce?: string;
  }) {
    let payload: { sub: string; email?: string | null };
    try {
          payload = await appleSignin.verifyIdToken(data.identityToken, {
            audience: env.APPLE_CLIENT_ID,
            ignoreExpiration: false,
            // The nonce is verified against the one signed into the
            // identityToken on the client — prevents auth replay.
            ...(data.nonce ? { nonce: data.nonce } : {}),
          });
        } catch {
          throw new UnauthorizedException('Invalid Apple identity token');
        }
        
        const appleId = payload.sub;
        const email = payload.email ?? `${appleId}@apple.local`;

        const existing = await db
              .select()
              .from(users)
              .where(or(eq(users.appleId, appleId), eq(users.email, email)))
              .limit(1)
              .then((r) => r[0]);
        
            let userId: string;
        
            if (existing) {
              userId = existing.id;
              await db
                .update(users)
                .set({
                  appleId: existing.appleId ?? appleId,
                  firstName: data.firstName ?? existing.firstName ?? '',
                  lastName: data.lastName ?? existing.lastName ?? '',
                })
                .where(eq(users.id, existing.id));
            } else {
              const created = await db
                .insert(users)
                .values({
                  email,
                  appleId,
                  firstName: data.firstName ?? '',
                  lastName: data.lastName ?? '',
                })
                .returning();
              const createdUser = created[0];
              if (!createdUser) throw new Error('Failed to create user');
              userId = createdUser.id;
            }
        
            const sessionId = randomUUID();
            const tokens = this.generateTokens(userId, sessionId);
            await this.createSession(userId, sessionId, tokens.refreshToken);
        
            return tokens;
          }

  
  async refresh(refreshToken: string) {
    try {
      const payload = await this.jwtService.verifyAsync<AuthPayload>(
        refreshToken,
        { secret: env.JWT_REFRESH_SECRET },
      );

      const hash = this.hashRefreshToken(refreshToken);
      const now = new Date();
      const tokens = this.generateTokens(payload.userId, payload.sessionId);
      const rotation = await db
        .update(authSessions)
        .set({
          refreshTokenHash: this.hashRefreshToken(tokens.refreshToken),
          previousRefreshTokenHash: hash,
          previousValidUntil: new Date(now.getTime() + this.reuseGraceTtl * 1000),
          updatedAt: now,
        })
        .where(
          and(
            eq(authSessions.userId, payload.userId),
            eq(authSessions.sessionId, payload.sessionId),
            eq(authSessions.refreshTokenHash, hash),
            isNull(authSessions.revokedAt),
            gt(authSessions.expiresAt, now),
          ),
        )
        .returning({ id: authSessions.id });

      if (rotation[0]) return tokens;

      const [session] = await db
        .select({
          previousRefreshTokenHash: authSessions.previousRefreshTokenHash,
          previousValidUntil: authSessions.previousValidUntil,
        })
        .from(authSessions)
        .where(
          and(
            eq(authSessions.userId, payload.userId),
            eq(authSessions.sessionId, payload.sessionId),
            isNull(authSessions.revokedAt),
          ),
        )
        .limit(1);

      // A duplicate in-flight refresh can arrive after the first request has
      // rotated the row. Do not revoke a healthy session during this short
      // grace period; the client should retain the token pair from the first
      // successful response.
      if (
        session?.previousRefreshTokenHash === hash
        && session.previousValidUntil != null
        && session.previousValidUntil > now
      ) {
        throw new UnauthorizedException('Refresh token was already rotated');
      }

      // A signed refresh token that no longer matches the current hash is a
      // replay attempt. Revoke its session so it cannot mint more tokens.
      await this.revokeSession(payload.userId, payload.sessionId);
      throw new UnauthorizedException('Refresh token is no longer valid');
    } catch {
      throw new UnauthorizedException();
    }
  }

  async logout(userId: string, sessionId: string) {
    await this.revokeSession(userId, sessionId);
    return { message: 'Logged out' };
  }

  async logoutAll(userId: string) {
    await db
      .update(authSessions)
      .set({ revokedAt: new Date(), updatedAt: new Date() })
      .where(and(eq(authSessions.userId, userId), isNull(authSessions.revokedAt)));
    return { message: 'Logged out from all devices' };
  }

  async isSessionAlive(userId: string, sessionId: string): Promise<boolean> {
    const [session] = await db
      .select({ id: authSessions.id })
      .from(authSessions)
      .where(
        and(
          eq(authSessions.userId, userId),
          eq(authSessions.sessionId, sessionId),
          isNull(authSessions.revokedAt),
          gt(authSessions.expiresAt, new Date()),
        ),
      )
      .limit(1);

    return session !== undefined;
  }

  private async revokeSession(userId: string, sessionId: string) {
    await db
      .update(authSessions)
      .set({ revokedAt: new Date(), updatedAt: new Date() })
      .where(
        and(
          eq(authSessions.userId, userId),
          eq(authSessions.sessionId, sessionId),
          isNull(authSessions.revokedAt),
        ),
      );
  }

  private async createSession(
    userId: string,
    sessionId: string,
    refreshToken: string,
  ) {
    await db.insert(authSessions).values({
      userId,
      sessionId,
      refreshTokenHash: this.hashRefreshToken(refreshToken),
      expiresAt: new Date(Date.now() + this.refreshTtl * 1000),
    });
  }

  private hashRefreshToken(refreshToken: string) {
    return createHash('sha256').update(refreshToken).digest('hex');
  }

  private isUniqueViolation(error: unknown): boolean {
    return typeof error === 'object'
      && error !== null
      && 'code' in error
      && (error as { code?: unknown }).code === '23505';
  }

  private generateTokens(userId: string, sessionId: string) {
    const payload: AuthPayload = { userId, sessionId };

    const accessToken = this.jwtService.sign(payload, {
      secret: env.JWT_ACCESS_SECRET,
      expiresIn: env.JWT_ACCESS_EXPIRES as any,
    });

    const refreshToken = this.jwtService.sign(payload, {
      secret: env.JWT_REFRESH_SECRET,
      expiresIn: env.JWT_REFRESH_EXPIRES as any,
    });

    return { accessToken, refreshToken };
  }

  private refreshTtl = 604800;

  // Window accepting a parallel refresh: an old refresh token may be
  // replayed within it (race/duplicate request); after that a repeat is
  // treated as a replay and revokes the whole session.
  private reuseGraceTtl = 120;
}
