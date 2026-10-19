import { describe, expect, it } from 'bun:test';
import { HttpException } from '@nestjs/common';

import { AnalysisQuotaService } from './analysis-quota.service';
import { env } from '../config/env';

describe('AnalysisQuotaService', () => {
  it('allows exactly the daily limit, then blocks', () => {
    const quota = new AnalysisQuotaService();

    for (let i = 0; i < env.ANALYSIS_DAILY_LIMIT; i += 1) {
      quota.tryReserve('u1');
    }

    expect(quota.remaining('u1')).toBe(0);
    expect(() => quota.tryReserve('u1')).toThrow(HttpException);
  });

  it('counts concurrent reservations instead of letting them all through', () => {
    const quota = new AnalysisQuotaService();

    // Simulates a burst of requests arriving before any of them completes:
    // the reservation is taken synchronously, so the limit still holds.
    for (let i = 0; i < env.ANALYSIS_DAILY_LIMIT; i += 1) {
      expect(() => quota.tryReserve('u1')).not.toThrow();
    }

    expect(quota.remaining('u1')).toBe(0);
    expect(() => quota.tryReserve('u1')).toThrow(HttpException);
  });

  it('releases a reservation when an analysis fails', () => {
    const quota = new AnalysisQuotaService();

    quota.tryReserve('u1');
    expect(quota.remaining('u1')).toBe(env.ANALYSIS_DAILY_LIMIT - 1);

    quota.release('u1');
    expect(quota.remaining('u1')).toBe(env.ANALYSIS_DAILY_LIMIT);
  });

  it('never drops below zero when releasing more than reserved', () => {
    const quota = new AnalysisQuotaService();

    quota.release('u1');

    expect(quota.remaining('u1')).toBe(env.ANALYSIS_DAILY_LIMIT);
  });

  it('tracks users independently', () => {
    const quota = new AnalysisQuotaService();

    for (let i = 0; i < env.ANALYSIS_DAILY_LIMIT; i += 1) {
      quota.tryReserve('u1');
    }

    expect(quota.remaining('u1')).toBe(0);
    expect(quota.remaining('u2')).toBe(env.ANALYSIS_DAILY_LIMIT);
    expect(() => quota.tryReserve('u2')).not.toThrow();
  });

  it('reports the full limit before any analysis', () => {
    const quota = new AnalysisQuotaService();
    expect(quota.remaining('fresh')).toBe(env.ANALYSIS_DAILY_LIMIT);
  });
});
