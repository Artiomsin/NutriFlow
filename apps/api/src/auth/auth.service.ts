import { Injectable, UnauthorizedException, ConflictException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { randomUUID, createHash } from 'crypto';
import { OAuth2Client } from 'google-auth-library';

import { db } from '../db/db';
import { users } from '../db/schema/users';
import { eq, or } from 'drizzle-orm';

import type { AuthPayload } from './types/auth.types';
import { env } from '../config/env';
import { cacheGet, cacheSet, cacheDel, scanKeys, redis } from '../redis';

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
  
    const user = await db
      .insert(users)
      .values({
        email: data.email,
        passwordHash: hash,
        firstName: data.firstName,
        lastName: data.lastName,
      })
      .returning();
  
    const createdUser = user[0];
  
    if (!createdUser) {
      throw new Error('User creation failed');
    }
  
    const sessionId = randomUUID();
  
    const tokens = this.generateTokens(createdUser.id, sessionId);
  
    await this.saveRefresh(createdUser.id, sessionId, tokens.refreshToken);
  
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

    await this.saveRefresh(user.id, sessionId, tokens.refreshToken);

    return tokens;
  }

  async googleLogin(data: { idToken: string }) {
    const ticket = await this.googleClient.verifyIdToken({
      idToken: data.idToken,
      audience: env.GOOGLE_CLIENT_ID,
    });

    const payload = ticket.getPayload();

    if (!payload?.email) {
      throw new UnauthorizedException('Google email not available');
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
    await this.saveRefresh(userId, sessionId, tokens.refreshToken);

    return tokens;
  }

  async refresh(refreshToken: string) {
    try {
      const payload = await this.jwtService.verifyAsync<AuthPayload>(
        refreshToken,
        { secret: env.JWT_REFRESH_SECRET },
      );

      const key = this.getKey(payload.userId, payload.sessionId);

      const storedHash = await cacheGet<string>(key);

      if (!storedHash) throw new UnauthorizedException();

      const match = storedHash === createHash('sha256').update(refreshToken).digest('hex');

      if (!match) throw new UnauthorizedException();

      const tokens = this.generateTokens(payload.userId, payload.sessionId);

      await this.saveRefresh(
        payload.userId,
        payload.sessionId,
        tokens.refreshToken,
      );

      return tokens;
    } catch {
      throw new UnauthorizedException();
    }
  }

  async logout(userId: string, sessionId: string) {
    await cacheDel(this.getKey(userId, sessionId));
    return { message: 'Logged out' };
  }

  async logoutAll(userId: string) {
    const keys = await scanKeys(`refresh:${userId}:*`);
    for (const key of keys) {
      await cacheDel(key);
    }
    return { message: 'Logged out from all devices' };
  }

  private async saveRefresh(
    userId: string,
    sessionId: string,
    refreshToken: string,
  ) {
    const hash = createHash('sha256').update(refreshToken).digest('hex');
    await cacheSet(this.getKey(userId, sessionId), hash, 604800);
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

  private getKey(userId: string, sessionId: string) {
    return `refresh:${userId}:${sessionId}`;
  }
}