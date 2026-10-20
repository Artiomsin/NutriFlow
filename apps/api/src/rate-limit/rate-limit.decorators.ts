import { applyDecorators, SetMetadata } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import {
  RATE_LIMIT_SCOPE,
  USER_RATE_LIMIT,
  type UserRateLimitOptions,
} from './rate-limit.constants';

/** Limits an endpoint by client IP through the global Nest throttler guard. */
export function RateLimit(scope: string, limit: number, ttl: number) {
  return applyDecorators(
    SetMetadata(RATE_LIMIT_SCOPE, scope),
    Throttle({ default: { limit, ttl } }),
  );
}

/** Limits an authenticated endpoint by user ID after JwtAuthGuard succeeds. */
export function UserRateLimit(options: UserRateLimitOptions) {
  return SetMetadata(USER_RATE_LIMIT, options);
}
