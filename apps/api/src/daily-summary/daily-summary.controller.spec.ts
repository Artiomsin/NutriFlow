import { describe, expect, it, mock } from 'bun:test';
import { GUARDS_METADATA } from '@nestjs/common/constants';

import { JwtAuthGuard } from '../auth/jwt.guard';
import type { AuthPayload } from '../auth/types/auth.types';
import { DailySummaryController } from './daily-summary.controller';
import type { DailySummaryService } from './daily-summary.service';

function setup() {
  const dailySummaryService = {
    findToday: mock(async () => ({})),
    findByDate: mock(async () => ({})),
    findTodayDashboard: mock(async () => ({})),
    findRange: mock(async () => []),
  };

  const controller = new DailySummaryController(
    dailySummaryService as unknown as DailySummaryService,
  );

  return { controller, dailySummaryService };
}

const user = { userId: 'user-1', sessionId: 'session-1' } as AuthPayload;

describe('DailySummaryController guards', () => {
  it('applies JwtAuthGuard at the class level', () => {
    const guards = Reflect.getMetadata(GUARDS_METADATA, DailySummaryController);
    expect(guards).toContain(JwtAuthGuard);
  });
});

describe('DailySummaryController', () => {
  it('passes the date to findToday', async () => {
    const { controller, dailySummaryService } = setup();
    await controller.findToday(user, { date: '2026-01-01' });
    expect(dailySummaryService.findToday).toHaveBeenCalledWith(
      'user-1',
      '2026-01-01',
    );
  });

  it('passes the date to findByDate', async () => {
    const { controller, dailySummaryService } = setup();
    await controller.findByDate(user, { date: '2026-01-02' });
    expect(dailySummaryService.findByDate).toHaveBeenCalledWith(
      'user-1',
      '2026-01-02',
    );
  });

  it('passes the date to findTodayDashboard', async () => {
    const { controller, dailySummaryService } = setup();
    await controller.findTodayDashboard(user, { date: '2026-01-03' });
    expect(dailySummaryService.findTodayDashboard).toHaveBeenCalledWith(
      'user-1',
      '2026-01-03',
    );
  });

  it('passes the range to findRange', async () => {
    const { controller, dailySummaryService } = setup();
    await controller.findRange(user, {
      from: '2026-01-01',
      to: '2026-01-10',
    });
    expect(dailySummaryService.findRange).toHaveBeenCalledWith(
      'user-1',
      '2026-01-01',
      '2026-01-10',
    );
  });
});
