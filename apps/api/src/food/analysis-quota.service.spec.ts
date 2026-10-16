import { describe, expect, it } from 'bun:test';
import { HttpException } from '@nestjs/common';

import { AnalysisQuotaService } from './analysis-quota.service';
import { env } from '../config/env';

describe('AnalysisQuotaService', () => {
  it('allows exactly the daily limit, then blocks', () => {
    const quota = new AnalysisQuotaService();

    for (let i = 0; i < env.ANALYSIS_DAILY_LIMIT; i += 1) {
      quota.assertAllowed('u1');
      quota.consume('u1');
    }

    expect(quota.remaining('u1')).toBe(0);
    expect(() => quota.assertAllowed('u1')).toThrow(HttpException);
  });

  it('tracks users independently', () => {
    const quota = new AnalysisQuotaService();

    for (let i = 0; i < env.ANALYSIS_DAILY_LIMIT; i += 1) {
      quota.consume('u1');
    }

    expect(quota.remaining('u1')).toBe(0);
    expect(quota.remaining('u2')).toBe(env.ANALYSIS_DAILY_LIMIT);
    expect(() => quota.assertAllowed('u2')).not.toThrow();
  });

  it('reports the full limit before any analysis', () => {
    const quota = new AnalysisQuotaService();
    expect(quota.remaining('fresh')).toBe(env.ANALYSIS_DAILY_LIMIT);
  });
});
