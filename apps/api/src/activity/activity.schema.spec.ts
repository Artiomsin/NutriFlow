import { describe, expect, it } from 'bun:test';

import {
  optionalDateQuerySchema,
  rangeQuerySchema,
  syncActivitySchema,
  syncEntrySchema,
} from './activity.schema';

describe('syncEntrySchema', () => {
  it('accepts a minimal entry and a fully populated one', () => {
    expect(syncEntrySchema.safeParse({ date: '2026-01-01' }).success).toBe(
      true,
    );
    expect(
      syncEntrySchema.safeParse({
        date: '2026-01-01',
        steps: 8421,
        activeCalories: 512,
        basalCalories: 1730,
        distanceMeters: 6123.45,
      }).success,
    ).toBe(true);
  });

  it('rejects negative and non-integer counters', () => {
    expect(
      syncEntrySchema.safeParse({ date: '2026-01-01', steps: -1 }).success,
    ).toBe(false);
    expect(
      syncEntrySchema.safeParse({ date: '2026-01-01', steps: 1.5 }).success,
    ).toBe(false);
    expect(
      syncEntrySchema.safeParse({ date: '2026-01-01', activeCalories: -10 })
        .success,
    ).toBe(false);
  });

  it('rejects an invalid calendar date', () => {
    expect(syncEntrySchema.safeParse({ date: '2026-02-30' }).success).toBe(
      false,
    );
    expect(syncEntrySchema.safeParse({ date: '01-01-2026' }).success).toBe(
      false,
    );
  });

  it('enforces the upper bounds mirrored from the database', () => {
    const at = (metrics: Record<string, number>) =>
      syncEntrySchema.safeParse({ date: '2026-01-01', ...metrics }).success;

    expect(at({ steps: 200_000 })).toBe(true);
    expect(at({ steps: 200_001 })).toBe(false);
    expect(at({ activeCalories: 20_000 })).toBe(true);
    expect(at({ activeCalories: 20_001 })).toBe(false);
    expect(at({ basalCalories: 20_000 })).toBe(true);
    expect(at({ basalCalories: 20_001 })).toBe(false);
    expect(at({ distanceMeters: 1_000_000 })).toBe(true);
    expect(at({ distanceMeters: 1_000_001 })).toBe(false);
  });
});

describe('syncActivitySchema', () => {
  const entry = (date: string) => ({ date });

  it('accepts between 1 and 31 entries', () => {
    expect(
      syncActivitySchema.safeParse({ entries: [entry('2026-01-01')] }).success,
    ).toBe(true);
    expect(
      syncActivitySchema.safeParse({
        entries: Array.from({ length: 31 }, (_, i) => ({
          date: `2026-01-${String((i % 28) + 1).padStart(2, '0')}`,
        })),
      }).success,
    ).toBe(true);
  });

  it('rejects an empty list and more than 31 entries', () => {
    expect(syncActivitySchema.safeParse({ entries: [] }).success).toBe(false);
    expect(
      syncActivitySchema.safeParse({
        entries: Array.from({ length: 32 }, () => ({ date: '2026-01-01' })),
      }).success,
    ).toBe(false);
  });
});

describe('rangeQuerySchema', () => {
  it('accepts an ordered range', () => {
    expect(
      rangeQuerySchema.safeParse({ from: '2026-01-01', to: '2026-01-31' })
        .success,
    ).toBe(true);
  });

  it('rejects a reversed range and missing bounds', () => {
    expect(
      rangeQuerySchema.safeParse({ from: '2026-02-01', to: '2026-01-31' })
        .success,
    ).toBe(false);
    expect(rangeQuerySchema.safeParse({ from: '2026-01-01' }).success).toBe(
      false,
    );
    expect(rangeQuerySchema.safeParse({}).success).toBe(false);
  });
});

describe('optionalDateQuerySchema', () => {
  it('accepts an omitted or valid date and rejects a malformed one', () => {
    expect(optionalDateQuerySchema.safeParse({}).success).toBe(true);
    expect(
      optionalDateQuerySchema.safeParse({ date: '2026-01-01' }).success,
    ).toBe(true);
    expect(
      optionalDateQuerySchema.safeParse({ date: '2026-13-01' }).success,
    ).toBe(false);
  });
});
