import { HttpException, HttpStatus, Injectable, ServiceUnavailableException } from '@nestjs/common';
import { redis } from '../redis';

@Injectable()
export class AuthRateLimitService {
  async checkLogin(ip: string): Promise<void> {
    await this.check(`auth:rate:login:${ip}`, 10, 15 * 60);
  }

  async checkRegister(ip: string): Promise<void> {
    await this.check(`auth:rate:register:${ip}`, 10, 60 * 60);
  }

  async checkGoogle(ip: string): Promise<void> {
    await this.check(`auth:rate:google:${ip}`, 30, 15 * 60);
  }

  async checkApple(ip: string): Promise<void> {
    await this.check(`auth:rate:apple:${ip}`, 30, 15 * 60);
  }

  async checkRefresh(ip: string): Promise<void> {
    await this.check(`auth:rate:refresh:${ip}`, 30, 60);
  }

  private async check(key: string, limit: number, windowSeconds: number): Promise<void> {
    try {
      const count = await redis.incr(key);
      if (count === 1) await redis.expire(key, windowSeconds);
      if (count > limit) {
        throw new HttpException(
          'Too many requests. Please try again later.',
          HttpStatus.TOO_MANY_REQUESTS,
        );
      }
    } catch (error) {
      if (error instanceof HttpException) throw error;
      throw new ServiceUnavailableException('Authentication is temporarily unavailable');
    }
  }
}
