import { drizzle } from 'drizzle-orm/node-postgres';
import { Pool } from 'pg';
import * as schema from './schema';

export function createPool(connectionString: string): Pool {
  const databaseUrl = new URL(connectionString);
  databaseUrl.searchParams.set('statement_timeout', '10000');

  return new Pool({
    connectionString: databaseUrl.toString(),
    max: 5,
    connectionTimeoutMillis: 15000,
    idleTimeoutMillis: 30000,
  });
}

export function createDb(pool: Pool) {
  return drizzle(pool, { schema });
}

export type Db = ReturnType<typeof createDb>;
export type Transaction = Parameters<Parameters<Db['transaction']>[0]>[0];
