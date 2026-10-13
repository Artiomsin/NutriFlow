import { Test } from '@nestjs/testing';
import type { TestingModule } from '@nestjs/testing';
import type { ModuleMetadata } from '@nestjs/common';
import { DB, DB_POOL } from '../../src/db/db.module';

export async function createTestModule(
  metadata: ModuleMetadata,
  tx: unknown,
): Promise<TestingModule> {
  return Test.createTestingModule(metadata)
    .overrideProvider(DB_POOL)
    .useValue({ end: async () => {} })
    .overrideProvider(DB)
    .useValue(tx)
    .compile();
}
