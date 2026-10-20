import { createHash } from 'node:crypto';
import { Injectable, HttpException, HttpStatus } from '@nestjs/common';
import type { CanActivate, ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PostgresThrottlerStorage } from './postgres-throttler.storage';
import {
  USER_RATE_LIMIT,
  type UserRateLimitOptions,
} from './rate-limit.constants';

@Injectable()
export class UserRateLimitGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly storage: PostgresThrottlerStorage,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const options = this.reflector.getAllAndOverride<UserRateLimitOptions>(
      USER_RATE_LIMIT,
      [context.getHandler(), context.getClass()],
    );
    if (!options) return true;

    const req = context.switchToHttp().getRequest<{
      user?: { userId?: string };
    }>();
    const res = context.switchToHttp().getResponse<{
      setHeader(name: string, value: string | number): void;
    }>();
    const userId = req.user?.userId;
    if (!userId) return true;

    const key = createHash('sha256')
      .update(`user:${options.scope}:${userId}`)
      .digest('hex');
    const counter = await this.storage.increment(
      key,
      options.ttl,
      options.limit,
    );

    res.setHeader('X-RateLimit-Limit', options.limit);
    res.setHeader(
      'X-RateLimit-Remaining',
      Math.max(0, options.limit - counter.totalHits),
    );
    res.setHeader('X-RateLimit-Reset', counter.timeToExpire);

    if (counter.isBlocked) {
      res.setHeader('Retry-After', counter.timeToBlockExpire);
      throw new HttpException(
        'Too many requests. Please try again later.',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
    return true;
  }
}
