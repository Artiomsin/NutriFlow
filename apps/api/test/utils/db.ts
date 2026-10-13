import { Pool } from 'pg';
import { drizzle } from 'drizzle-orm/node-postgres';
import * as schema from '../../src/db/schema';

const url = process.env.TEST_DATABASE_URL ?? process.env.DATABASE_URL;
if (!url) throw new Error('TEST_DATABASE_URL or DATABASE_URL must be set');

export const testPool = new Pool({ connectionString: url });

export async function openTx() {
  const client = await testPool.connect();
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
}

export async function closePool() {
  await testPool.end();
}
