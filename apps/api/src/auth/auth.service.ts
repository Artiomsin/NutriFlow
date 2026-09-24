import { Injectable, UnauthorizedException, ConflictException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { randomUUID, createHash } from 'crypto';
import { OAuth2Client } from 'google-auth-library';
import appleSignin from 'apple-signin-auth';

import { db } from '../db/db';
import { users } from '../db/schema/users';
import { eq, or } from 'drizzle-orm';

import type { AuthPayload } from './types/auth.types';
import { env } from '../config/env';
import { cacheGet, cacheSet, cacheDel, cacheDelByPrefix, scanKeys } from '../redis';
import { invalidateLocalSession, invalidateAllSessions } from '../session-store';

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
    await this.saveRefresh(userId, sessionId, tokens.refreshToken);

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
            // nonce сверяется с тем, что был подписан в identityToken
            // при входе на клиенте — защита от replay авторизации.
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
      const hash = this.hashRefreshToken(refreshToken);

      const storedHash = await cacheGet<string>(key);

      if (!storedHash) throw new UnauthorizedException();

      if (storedHash === hash) {
        // Ротация: выдаём новую пару, фиксируем пред. токен и выдаваемую пару
        // лишь на короткое окно приёма параллельного refresh (гонка).
        const tokens = this.generateTokens(payload.userId, payload.sessionId);
        // Хеш предыдущего refresh держим до конца жизни сессии: это позволяет
        // отличить реплей старого токена после grace-окна от неизвестного токена.
        await cacheSet(this.getPrevKey(key), storedHash, this.refreshTtl);
        await cacheSet(this.getUsedKey(key, storedHash), true, this.refreshTtl);
        await cacheSet(this.getPairKey(key), tokens, this.reuseGraceTtl);
        await this.saveRefresh(
          payload.userId,
          payload.sessionId,
          tokens.refreshToken,
        );
        return tokens;
      }

      // Токен уже был ротирован.
      const prevHash = await cacheGet<string>(this.getPrevKey(key));
      if (prevHash === hash) {
        const pair = await cacheGet<{ accessToken: string; refreshToken: string }>(
          this.getPairKey(key),
        );
        // Повтор старого токена в пределах короткого grace-окна — это
        // легитимная гонка параллельных refresh: отдаём ту же пару.
        if (pair) return pair;

        // Повтор после истечения grace-окна — это компрометация токена
        // (реплей ротированного refresh). Отзываем всю сессию.
        await this.revokeSession(payload.userId, payload.sessionId);
        throw new UnauthorizedException('refresh token reuse detected');
      }

      // Любой токен из более ранней ротации означает compromise: хеши
      // использованных refresh живут до конца TTL сессии.
      const wasUsed = await cacheGet<boolean>(this.getUsedKey(key, hash));
      if (wasUsed) {
        await this.revokeSession(payload.userId, payload.sessionId);
        throw new UnauthorizedException('refresh token reuse detected');
      }

      throw new UnauthorizedException();
    } catch {
      throw new UnauthorizedException();
    }
  }

  async logout(userId: string, sessionId: string) {
    await this.revokeSession(userId, sessionId);
    return { message: 'Logged out' };
  }

  async logoutAll(userId: string) {
    const keys = await scanKeys(`refresh:${userId}:*`);
    for (const key of keys) {
      await cacheDel(key);
    }
    invalidateAllSessions(userId);
    return { message: 'Logged out from all devices' };
  }

  private async revokeSession(userId: string, sessionId: string) {
    const key = this.getKey(userId, sessionId);
    await cacheDel(key);
    await cacheDel(this.getPrevKey(key));
    await cacheDel(this.getPairKey(key));
    await cacheDelByPrefix(`${key}:used:`);
    invalidateLocalSession(userId, sessionId);
  }

  private async saveRefresh(
    userId: string,
    sessionId: string,
    refreshToken: string,
  ) {
    await cacheSet(
      this.getKey(userId, sessionId),
      this.hashRefreshToken(refreshToken),
      this.refreshTtl,
    );
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

  private getKey(userId: string, sessionId: string) {
    return `refresh:${userId}:${sessionId}`;
  }

  private getPrevKey(key: string) {
    return `${key}:prev`;
  }

  private getPairKey(key: string) {
    return `${key}:pair`;
  }

  private getUsedKey(key: string, hash: string) {
    return `${key}:used:${hash}`;
  }

  private refreshTtl = 604800;

  // Окно приёма параллельного refresh: старый refresh-токен можно повторно
  // передать в течение этого времени (гонка/дубликат запроса), после чего
  // повтор расценивается как реплей и отзывает всю сессию.
  private reuseGraceTtl = 120;
}
