import { Test } from '@nestjs/testing';
import type { TestingModule } from '@nestjs/testing';
import type { ModuleMetadata } from '@nestjs/common';
import { DB, DB_POOL } from '../../src/db/db.module';

/**
 * Wraps the test transaction so that a service-level `db.transaction(cb)` call
 * reuses the already-open outer transaction instead of issuing its own
 * BEGIN/COMMIT. Otherwise drizzle would COMMIT the outer test transaction,
 * leaking rows into the database and breaking per-file isolation.
 */
function isolate(tx: unknown): unknown {
  let handle: unknown;
  handle = new Proxy(tx as object, {
    get(target, prop) {
      if (prop === 'transaction') {
        return (cb: (t: unknown) => unknown) => cb(handle);
      }
      const value = Reflect.get(target, prop, target);
      return typeof value === 'function' ? value.bind(target) : value;
    },
  });
  return handle;
}

export async function createTestModule(
  metadata: ModuleMetadata,
  tx: unknown,
): Promise<TestingModule> {
  return Test.createTestingModule(metadata)
    .overrideProvider(DB_POOL)
    .useValue({ end: async () => {} })
    .overrideProvider(DB)
    .useValue(isolate(tx))
    .compile();
}
