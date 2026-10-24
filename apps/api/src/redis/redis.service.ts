import { Inject, Injectable, Logger } from '@nestjs/common';
import type { OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import Redis from 'ioredis';

import { env } from '../config/env';
import {
  REDIS_CLIENT_FACTORY,
  type RedisClientFactory,
} from './redis.constants';

@Injectable()
export class RedisService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RedisService.name);
  private readonly client: Redis | null;
  private ready = false;

  constructor(
    @Inject(REDIS_CLIENT_FACTORY)
    createClient: RedisClientFactory,
  ) {
    if (!env.REDIS_URL) {
      this.client = null;
      return;
    }

    this.client = createClient(env.REDIS_URL);
    this.client.on('error', (error) => {
      this.ready = false;
      this.logger.warn(`Redis unavailable: ${error.message}`);
    });
  }

  get isReady(): boolean {
    return this.ready && this.client?.status === 'ready';
  }

  async onModuleInit(): Promise<void> {
    if (!this.client) {
      this.logger.log('Redis cache disabled: REDIS_URL is not configured');
      return;
    }

    try {
      await this.client.connect();
      const response = await this.client.ping();
      if (response !== 'PONG') {
        throw new Error(`Unexpected Redis PING response: ${response}`);
      }
      this.ready = true;
      this.logger.log('Redis connected: PING → PONG');
    } catch (error) {
      this.ready = false;
      this.logger.warn(
        `Redis cache unavailable; continuing without it: ${this.errorMessage(error)}`,
      );
      this.client.disconnect();
    }
  }

  async onModuleDestroy(): Promise<void> {
    this.ready = false;
    if (!this.client || this.client.status === 'end') return;

    await this.client.quit().catch(() => this.client?.disconnect());
  }

  async get(key: string): Promise<string | null> {
    if (!this.isReady || !this.client) return null;

    try {
      return await this.client.get(key);
    } catch (error) {
      this.logger.warn(`Redis GET failed: ${this.errorMessage(error)}`);
      return null;
    }
  }

  async set(key: string, value: string, ttlMs: number): Promise<void> {
    if (!this.isReady || !this.client || ttlMs <= 0) return;

    try {
      await this.client.set(key, value, 'PX', ttlMs);
    } catch (error) {
      this.logger.warn(`Redis SET failed: ${this.errorMessage(error)}`);
    }
  }

  async delete(key: string): Promise<void> {
    if (!this.isReady || !this.client) return;

    try {
      await this.client.del(key);
    } catch (error) {
      this.logger.warn(`Redis DEL failed: ${this.errorMessage(error)}`);
    }
  }

  private errorMessage(error: unknown): string {
    return error instanceof Error ? error.message : String(error);
  }
}
