import { describe, it, expect, afterAll } from 'bun:test';
import { sql } from 'drizzle-orm';
import { openTx, closePool } from '../utils/db';

afterAll(async () => {
  await closePool();
});

describe('test db rollback isolation', () => {
  it('runs a query inside a rolled-back tx', async () => {
    const { tx, rollback } = await openTx();
    try {
      const res = await tx.execute(sql`select 1 as ok`);
      expect(res.rows[0]?.ok).toBe(1);
    } finally {
      await rollback();
    }
  });
});
