import { describe, it, expect } from 'bun:test';
import { formatDateInTimeZone } from './user-date';

describe('formatDateInTimeZone', () => {
  it('formats date in UTC', () => {
    expect(formatDateInTimeZone(new Date('2026-01-02T03:04:05Z'), 'UTC')).toBe(
      '2026-01-02',
    );
  });
});
