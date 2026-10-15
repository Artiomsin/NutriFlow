import { describe, expect, it } from 'bun:test';

import {
  createWeightLogSchema,
  listWeightLogsSchema,
  weightLogDateParamSchema,
} from './weight-logs.schema';

describe('createWeightLogSchema', () => {
  it('accepts a weight with an optional date', () => {
    expect(createWeightLogSchema.safeParse({ weightKg: 70 }).success).toBe(
      true,
    );
    expect(
      createWeightLogSchema.safeParse({ weightKg: 70, date: '2026-01-05' })
        .success,
    ).toBe(true);
  });

  it('rejects weight outside 20..400', () => {
    expect(createWeightLogSchema.safeParse({ weightKg: 19 }).success).toBe(
      false,
    );
    expect(createWeightLogSchema.safeParse({ weightKg: 401 }).success).toBe(
      false,
    );
  });

  it('rejects an invalid calendar date', () => {
    expect(
      createWeightLogSchema.safeParse({ weightKg: 70, date: '2026-02-30' })
        .success,
    ).toBe(false);
  });
});

describe('listWeightLogsSchema', () => {
  it('accepts an empty range and an ordered range', () => {
    expect(listWeightLogsSchema.safeParse({}).success).toBe(true);
    expect(
      listWeightLogsSchema.safeParse({ from: '2026-01-01', to: '2026-01-31' })
        .success,
    ).toBe(true);
  });

  it('rejects a range where from is after to', () => {
    expect(
      listWeightLogsSchema.safeParse({ from: '2026-02-01', to: '2026-01-31' })
        .success,
    ).toBe(false);
  });
});

describe('weightLogDateParamSchema', () => {
  it('accepts a valid date and rejects a malformed one', () => {
    expect(
      weightLogDateParamSchema.safeParse({ date: '2026-01-05' }).success,
    ).toBe(true);
    expect(
      weightLogDateParamSchema.safeParse({ date: '05-01-2026' }).success,
    ).toBe(false);
  });
});
