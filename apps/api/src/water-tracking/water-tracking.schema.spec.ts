import { describe, expect, it } from 'bun:test';

import {
  createWaterEntrySchema,
  optionalDateQuerySchema,
  requiredDateQuerySchema,
} from './water-tracking.schema';

describe('createWaterEntrySchema', () => {
  it('accepts a valid amount without a date', () => {
    expect(createWaterEntrySchema.safeParse({ amountMl: 500 }).success).toBe(
      true,
    );
  });

  it('accepts a valid amount with a date', () => {
    expect(
      createWaterEntrySchema.safeParse({
        amountMl: 500,
        date: '2026-01-01',
      }).success,
    ).toBe(true);
  });

  it('rejects zero, negative and excessive amounts', () => {
    expect(createWaterEntrySchema.safeParse({ amountMl: 0 }).success).toBe(
      false,
    );
    expect(createWaterEntrySchema.safeParse({ amountMl: -5 }).success).toBe(
      false,
    );
    expect(createWaterEntrySchema.safeParse({ amountMl: 3001 }).success).toBe(
      false,
    );
  });

  it('rejects a non-integer amount', () => {
    expect(createWaterEntrySchema.safeParse({ amountMl: 250.5 }).success).toBe(
      false,
    );
  });
});

describe('date query schemas', () => {
  it('allows an omitted date in the optional query', () => {
    expect(optionalDateQuerySchema.safeParse({}).success).toBe(true);
  });

  it('requires a date in the required query', () => {
    expect(requiredDateQuerySchema.safeParse({}).success).toBe(false);
    expect(
      requiredDateQuerySchema.safeParse({ date: '2026-01-01' }).success,
    ).toBe(true);
  });
});
