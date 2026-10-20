import { Injectable } from '@nestjs/common';
import { createHash } from 'node:crypto';
import {
  InjectThrottlerOptions,
  InjectThrottlerStorage,
  ThrottlerGuard,
  type ThrottlerModuleOptions,
  type ThrottlerStorage,
} from '@nestjs/throttler';
import { Reflector } from '@nestjs/core';
import { RATE_LIMIT_SCOPE } from './rate-limit.constants';

/** Uses Express's proxy-aware req.ip, configured in main.ts for Render. */
@Injectable()
export class RateLimitGuard extends ThrottlerGuard {
  constructor(
    @InjectThrottlerOptions()
    options: ThrottlerModuleOptions,
    @InjectThrottlerStorage() storageService: ThrottlerStorage,
    reflector: Reflector,
  ) {
    super(options, storageService, reflector);
  }

  protected override generateKey(
    context: Parameters<ThrottlerGuard['generateKey']>[0],
    tracker: string,
    throttlerName: string,
  ): string {
    const scope =
      this.reflector.getAllAndOverride<string>(RATE_LIMIT_SCOPE, [
        context.getHandler(),
        context.getClass(),
      ]) ?? 'global';

    return createHash('sha256')
      .update(`${throttlerName}:${scope}:${tracker}`)
      .digest('hex');
  }
}
