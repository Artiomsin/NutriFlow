import { ConfigModule } from '@nestjs/config';
import type { TestingModule } from '@nestjs/testing';

import { AuthModule } from '../../src/auth/auth.module';
import { DbModule } from '../../src/db/db.module';
import { createTestModule } from './app';

/**
 * Builds a Nest testing module with the real AuthModule wired to an isolated
 * transaction. The database provider is overridden with `tx`, so every write
 * performed by the auth services happens inside the caller's transaction and
 * is discarded on rollback.
 */
export async function createAuthTestingModule(
  tx: unknown,
): Promise<TestingModule> {
  return createTestModule(
    {
      imports: [ConfigModule.forRoot({ isGlobal: true }), DbModule, AuthModule],
    },
    tx,
  );
}
