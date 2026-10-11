import { Global, Inject, Module } from '@nestjs/common';
import type { OnApplicationShutdown } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Pool } from 'pg';
import { createDb, createPool, type Db } from './db';

export const DB_POOL = Symbol('DB_POOL');
export const DB = Symbol('DB');

@Global()
@Module({
  providers: [
    {
      provide: DB_POOL,
      useFactory: (config: ConfigService) =>
        createPool(config.getOrThrow<string>('DATABASE_URL')),
      inject: [ConfigService],
    },
    {
      provide: DB,
      useFactory: (pool: Pool): Db => createDb(pool),
      inject: [DB_POOL],
    },
  ],
  exports: [DB],
})
export class DbModule implements OnApplicationShutdown {
  constructor(@Inject(DB_POOL) private readonly pool: Pool) {}

  async onApplicationShutdown(): Promise<void> {
    await this.pool.end();
  }
}
