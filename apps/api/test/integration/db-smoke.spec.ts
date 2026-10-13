import { afterAll, describe, expect, it } from 'bun:test';
import { sql } from 'drizzle-orm';
import { createTestDb } from '../utils/db';

const db = createTestDb();

afterAll(async () => {
  await db.close();
});

describe('test db rollback isolation', () => {
  it('runs a query inside a rolled-back tx', async () => {
    const { tx, rollback } = await db.openTx();
    try {
      const res = await tx.execute(sql`select 1 as ok`);
      expect(res.rows[0]?.ok).toBe(1);
    } finally {
      await rollback();
    }
  });
});
