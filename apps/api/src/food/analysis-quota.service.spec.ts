import { describe, expect, it } from 'bun:test';
import { HttpException } from '@nestjs/common';

import { AnalysisQuotaService } from './analysis-quota.service';
import { env } from '../config/env';

const databaseReturning = (rows: unknown[]) => ({
  execute: async () => ({ rows }),
});

describe('AnalysisQuotaService', () => {
  it('reports the full limit when there is no quota row for today', async () => {
    const quota = new AnalysisQuotaService(databaseReturning([]) as never);

    expect(await quota.remaining('user-id')).toBe(env.ANALYSIS_DAILY_LIMIT);
  });

  it('returns the remaining daily allowance from PostgreSQL', async () => {
    const quota = new AnalysisQuotaService(
      databaseReturning([{ count: 2 }]) as never,
    );

    expect(await quota.remaining('user-id')).toBe(env.ANALYSIS_DAILY_LIMIT - 2);
  });

  it('accepts a reservation when PostgreSQL atomically increments it', async () => {
    const quota = new AnalysisQuotaService(
      databaseReturning([{ count: 1 }]) as never,
    );

    await expect(quota.tryReserve('user-id')).resolves.toBeUndefined();
  });

  it('returns 429 when the atomic database increment reaches the limit', async () => {
    const quota = new AnalysisQuotaService(databaseReturning([]) as never);

    await expect(quota.tryReserve('user-id')).rejects.toBeInstanceOf(
      HttpException,
    );
  });

  it('releases a reservation with a database update', async () => {
    const quota = new AnalysisQuotaService(databaseReturning([]) as never);

    await expect(quota.release('user-id')).resolves.toBeUndefined();
  });
});
