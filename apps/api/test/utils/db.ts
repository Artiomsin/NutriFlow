import { Pool } from 'pg';
import { drizzle } from 'drizzle-orm/node-postgres';
import type { NodePgDatabase } from 'drizzle-orm/node-postgres';
import * as schema from '../../src/db/schema';

export type TestTx = NodePgDatabase<typeof schema>;

export type TestDb = {
  pool: Pool;
  openTx(): Promise<{ tx: TestTx; rollback(): Promise<void> }>;
  close(): Promise<void>;
};

/**
 * Creates an isolated test database handle backed by its own connection pool.
 * Each spec file should create its own instance so that closing one pool does
 * not affect other spec files.
 */
export function createTestDb(): TestDb {
  const url = process.env.TEST_DATABASE_URL ?? process.env.DATABASE_URL;
  if (!url) throw new Error('TEST_DATABASE_URL or DATABASE_URL must be set');

  const pool = new Pool({ connectionString: url });

  return {
    pool,
    async openTx() {
      const client = await pool.connect();
      await client.query('BEGIN');
      const tx = drizzle(client, { schema });
      return {
        tx,
        async rollback() {
          try {
            await client.query('ROLLBACK');
          } finally {
            client.release();
          }
        },
      };
    },
    async close() {
      await pool.end();
    },
  };
}
