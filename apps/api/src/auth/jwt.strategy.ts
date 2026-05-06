import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';

import  type { AuthPayload } from './types/auth.types';
import { env } from '../config/env';
import { redis } from '../redis';

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
    console.log('JWT VALIDATE:', payload);
    const exists = await redis.get(key);

    if (!exists) {
      throw new UnauthorizedException('Session expired');
    }

    return payload;
  }
}