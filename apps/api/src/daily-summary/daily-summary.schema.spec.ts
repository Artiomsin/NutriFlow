import { describe, expect, it } from 'bun:test';

import { dateQuerySchema, rangeQuerySchema } from './daily-summary.schema';

describe('dateQuerySchema', () => {
  it('accepts an omitted date', () => {
    expect(dateQuerySchema.safeParse({}).success).toBe(true);
  });

  it('rejects a malformed date', () => {
    expect(dateQuerySchema.safeParse({ date: '2026/01/01' }).success).toBe(
      false,
    );
  });
});

describe('rangeQuerySchema', () => {
  it('accepts a valid range', () => {
    const result = rangeQuerySchema.safeParse({
      from: '2026-01-01',
      to: '2026-01-10',
    });
    expect(result.success).toBe(true);
  });

  it('accepts a range of exactly 365 days', () => {
    const result = rangeQuerySchema.safeParse({
      from: '2026-01-01',
      to: '2026-12-31',
    });
    expect(result.success).toBe(true);
  });

  it('rejects from after to with the "to" path', () => {
    const result = rangeQuerySchema.safeParse({
      from: '2026-01-10',
      to: '2026-01-01',
    });
    expect(result.success).toBe(false);
    if (!result.success) {
      expect(result.error.issues[0]?.path).toEqual(['to']);
      expect(result.error.issues[0]?.message).toBe('from must not be after to');
    }
  });

  it('rejects a range wider than 366 days', () => {
    const result = rangeQuerySchema.safeParse({
      from: '2026-01-01',
      to: '2027-06-01',
    });
    expect(result.success).toBe(false);
    if (!result.success) {
      expect(result.error.issues[0]?.path).toEqual(['to']);
    }
  });
});
