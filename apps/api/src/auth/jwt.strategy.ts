import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';

import  type { AuthPayload } from './types/auth.types';
import { env } from '../config/env';
import { cacheGet } from '../redis';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, 'jwt') {
  constructor() {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      secretOrKey: env.JWT_ACCESS_SECRET,
    });
  }

  async validate(payload: AuthPayload): Promise<AuthPayload> {
    
    const key = `refresh:${payload.userId}:${payload.sessionId}`;
    const exists = await cacheGet<string>(key);

    if (!exists) {
      throw new UnauthorizedException('Session expired');
    }

    return payload;
  }
}