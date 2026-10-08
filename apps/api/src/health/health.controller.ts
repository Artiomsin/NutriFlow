import { Controller, Get, ServiceUnavailableException } from '@nestjs/common';
import { sql } from 'drizzle-orm';
import { db } from '../db/db';
import { redis } from '../redis';

@Controller('health')
export class HealthController {
  @Get()
  live() {
    return { status: 'ok' };
  }

  @Get('ready')
  async ready() {
    try {
      await Promise.all([
        db.execute(sql`SELECT 1`),
        redis.ping(),
      ]);
      return { status: 'ready' };
    } catch {
      throw new ServiceUnavailableException({ status: 'not_ready' });
    }
  }
}
