import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';

import type { AuthPayload } from './types/auth.types';
import { env } from '../config/env';
import { AuthService } from './auth.service';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, 'jwt') {
  constructor(private readonly authService: AuthService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      secretOrKey: env.JWT_ACCESS_SECRET,
    });
  }

  async validate(payload: AuthPayload): Promise<AuthPayload> {
    const alive = await this.authService.isSessionAlive(
      payload.userId,
      payload.sessionId,
    );

    if (!alive) {
      throw new UnauthorizedException('Session expired');
    }

    return payload;
  }
}
