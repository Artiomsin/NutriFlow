import { describe, expect, it, mock } from 'bun:test';
import { HttpException } from '@nestjs/common';

import { AnalysisQuotaService } from './analysis-quota.service';
import { env } from '../config/env';

const reservation = {
  id: 'b1cfa54c-0b86-4115-b81e-5a55b6d6c0d9',
  reservedAt: new Date('2026-10-22T10:00:00.000Z'),
};

function databaseReturning(rows: unknown[]) {
  const execute = mock(async () => ({ rows }));
  return {
    execute,
    transaction: async (
      callback: (tx: { execute: typeof execute }) => unknown,
    ) => callback({ execute }),
  };
}

function reservingDatabase(activeCount: number, inserted = reservation) {
  const execute = mock(async () => ({ rows: [] as unknown[] }));
  execute.mockResolvedValueOnce({ rows: [] });
  execute.mockResolvedValueOnce({ rows: [{ count: activeCount }] });
  execute.mockResolvedValueOnce({ rows: [inserted] });
  return {
    execute,
    transaction: async (
      callback: (tx: { execute: typeof execute }) => unknown,
    ) => callback({ execute }),
  };
}

describe('AnalysisQuotaService', () => {
  it('reports the full limit when no rolling reservations are active', async () => {
    const quota = new AnalysisQuotaService(
      databaseReturning([{ count: 0 }]) as never,
    );

    expect(await quota.remaining('user-id')).toBe(env.ANALYSIS_DAILY_LIMIT);
  });

  it('returns the remaining rolling allowance from PostgreSQL', async () => {
    const quota = new AnalysisQuotaService(
      databaseReturning([{ count: 2 }]) as never,
    );

    expect(await quota.remaining('user-id')).toBe(env.ANALYSIS_DAILY_LIMIT - 2);
  });

  it('creates a pending reservation below the rolling limit', async () => {
    const quota = new AnalysisQuotaService(reservingDatabase(1) as never);

    await expect(quota.tryReserve('user-id')).resolves.toEqual(reservation);
  });

  it('returns 429 when active reservations reach the rolling limit', async () => {
    const quota = new AnalysisQuotaService(
      reservingDatabase(env.ANALYSIS_DAILY_LIMIT) as never,
    );

    await expect(quota.tryReserve('user-id')).rejects.toBeInstanceOf(
      HttpException,
    );
  });

  it('consumes and releases the exact reservation', async () => {
    const database = databaseReturning([]);
    const quota = new AnalysisQuotaService(database as never);

    await quota.consume('user-id', reservation);
    await quota.release('user-id', reservation);

    expect(database.execute).toHaveBeenCalledTimes(2);
  });
});
