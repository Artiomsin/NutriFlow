import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { randomUUID } from 'crypto';

import { db } from '../db/db';
import { users } from '../db/schema/users';
import { eq } from 'drizzle-orm';

import  type { AuthPayload } from './types/auth.types';
import { env } from '../config/env';
import { redis } from '../redis';

@Injectable()
export class AuthService {
  constructor(private jwtService: JwtService) {}

  async register(data: {
    email: string;
    password: string;
    firstName: string;
    lastName: string;
  }) {
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

    const valid = await bcrypt.compare(data.password, user.passwordHash);

    if (!valid) throw new UnauthorizedException();

    const sessionId = randomUUID();

    const tokens = this.generateTokens(user.id, sessionId);

    await this.saveRefresh(user.id, sessionId, tokens.refreshToken);

    return tokens;
  }


  async refresh(refreshToken: string) {
    try {
      const payload = await this.jwtService.verifyAsync<AuthPayload>(
        refreshToken,
        { secret: env.JWT_REFRESH_SECRET },
      );

      const key = this.getKey(payload.userId, payload.sessionId);

      const storedHash = await redis.get(key);

      if (!storedHash) throw new UnauthorizedException();

      const match = await bcrypt.compare(refreshToken, storedHash);

      if (!match) throw new UnauthorizedException();

     
      await redis.del(key);

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
    const key = this.getKey(userId, sessionId);

    await redis.del(key);

    return { message: 'Logged out' };
  }

  async logoutAll(userId: string) {
   

    const pattern = `refresh:${userId}:*`;

    const keys = await this.scanKeys(pattern);

    if (keys.length) {
      await redis.del(...keys);
    }

    return { message: 'Logged out from all devices' };
  }


  private async saveRefresh(
    userId: string,
    sessionId: string,
    refreshToken: string,
  ) {
    const hash = await bcrypt.hash(refreshToken, 10);

    const key = this.getKey(userId, sessionId);

    await redis.set(key, hash, 'EX', 60 * 60 * 24 * 7);
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

  private async scanKeys(pattern: string): Promise<string[]> {
    const keys: string[] = [];

    let cursor = 0;

    do {
      const [nextCursor, found] = await redis.scan(
        cursor,
        'MATCH',
        pattern,
        'COUNT',
        100,
      );

      cursor = Number(nextCursor);
      keys.push(...found);
    } while (cursor !== 0);

    return keys;
  }
}