import { HttpException, HttpStatus, Injectable, ServiceUnavailableException } from '@nestjs/common';
import { redis } from '../redis';

@Injectable()
export class FoodRateLimitService {
  async checkAnalyze(ip: string, userId: string): Promise<void> {
    await this.checkBoth('analyze', ip, userId, 30, 8, 15 * 60);
  }

  async checkUpload(ip: string, userId: string): Promise<void> {
    await this.checkBoth('upload', ip, userId, 120, 30, 15 * 60);
  }

  async checkSearch(ip: string, userId: string): Promise<void> {
    await this.checkBoth('search', ip, userId, 300, 60, 60);
  }

  private async checkBoth(
    operation: string,
    ip: string,
    userId: string,
    ipLimit: number,
    userLimit: number,
    windowSeconds: number,
  ): Promise<void> {
    await this.check(`food:rate:${operation}:ip:${ip}`, ipLimit, windowSeconds);
    await this.check(`food:rate:${operation}:user:${userId}`, userLimit, windowSeconds);
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
      throw new ServiceUnavailableException('Food service is temporarily unavailable');
    }
  }
}
