import { describe, expect, it } from 'bun:test';

import {
  deleteMissingSchema,
  historyQuerySchema,
  syncSleepEntrySchema,
  syncSleepSchema,
} from './sleep.schema';

const validNight = {
  startDate: '2026-01-01T22:30:00.000Z',
  endDate: '2026-01-02T06:30:00.000Z',
  localDate: '2026-01-02',
};

describe('syncSleepEntrySchema', () => {
  it('accepts a minimal night and one with every metric', () => {
    expect(syncSleepEntrySchema.safeParse(validNight).success).toBe(true);
    expect(
      syncSleepEntrySchema.safeParse({
        ...validNight,
        timeInBedSeconds: 28_800,
        asleepSeconds: 25_200,
        awakeSeconds: 3_600,
        coreSeconds: 14_400,
        deepSeconds: 5_400,
        remSeconds: 5_400,
        unspecifiedSeconds: 0,
        awakenings: 2,
        onsetLatencySeconds: 420,
        efficiency: 87.5,
        segmentCount: 4,
        heartRateAvg: 54.5,
      }).success,
    ).toBe(true);
  });

  it('treats the optional metrics as nullable', () => {
    expect(
      syncSleepEntrySchema.safeParse({
        ...validNight,
        asleepSeconds: null,
        awakenings: null,
        efficiency: null,
        heartRateAvg: null,
      }).success,
    ).toBe(true);
  });

  it('rejects an end before or equal to the start', () => {
    expect(
      syncSleepEntrySchema.safeParse({
        ...validNight,
        endDate: '2026-01-01T22:30:00.000Z',
      }).success,
    ).toBe(false);
    expect(
      syncSleepEntrySchema.safeParse({
        ...validNight,
        endDate: '2026-01-01T20:00:00.000Z',
      }).success,
    ).toBe(false);
  });

  it('rejects an ISO date-time without an offset', () => {
    expect(
      syncSleepEntrySchema.safeParse({
        ...validNight,
        startDate: '2026-01-01T22:30:00',
      }).success,
    ).toBe(false);
  });

  it('caps each stage duration at one day', () => {
    const withSeconds = (field: string, value: number) =>
      syncSleepEntrySchema.safeParse({ ...validNight, [field]: value }).success;

    expect(withSeconds('asleepSeconds', 86_400)).toBe(true);
    expect(withSeconds('asleepSeconds', 86_401)).toBe(false);
    expect(withSeconds('timeInBedSeconds', 86_400)).toBe(true);
    expect(withSeconds('timeInBedSeconds', 86_401)).toBe(false);
    expect(withSeconds('awakeSeconds', 86_401)).toBe(false);
    expect(withSeconds('coreSeconds', 86_401)).toBe(false);
    expect(withSeconds('deepSeconds', 86_401)).toBe(false);
    expect(withSeconds('remSeconds', 86_401)).toBe(false);
    expect(withSeconds('unspecifiedSeconds', 86_401)).toBe(false);
  });

  it('rejects negative durations and out-of-range quality metrics', () => {
    expect(
      syncSleepEntrySchema.safeParse({ ...validNight, asleepSeconds: -1 })
        .success,
    ).toBe(false);
    expect(
      syncSleepEntrySchema.safeParse({ ...validNight, efficiency: 100.5 })
        .success,
    ).toBe(false);
    expect(
      syncSleepEntrySchema.safeParse({ ...validNight, efficiency: -1 }).success,
    ).toBe(false);
    expect(
      syncSleepEntrySchema.safeParse({ ...validNight, heartRateAvg: 301 })
        .success,
    ).toBe(false);
    expect(
      syncSleepEntrySchema.safeParse({ ...validNight, awakenings: -1 }).success,
    ).toBe(false);
  });
});

describe('syncSleepSchema', () => {
  it('accepts between 1 and 50 nights', () => {
    expect(syncSleepSchema.safeParse({ nights: [validNight] }).success).toBe(
      true,
    );
    expect(
      syncSleepSchema.safeParse({
        nights: Array.from({ length: 50 }, () => validNight),
      }).success,
    ).toBe(true);
  });

  it('rejects an empty list and more than 50 nights', () => {
    expect(syncSleepSchema.safeParse({ nights: [] }).success).toBe(false);
    expect(
      syncSleepSchema.safeParse({
        nights: Array.from({ length: 51 }, () => validNight),
      }).success,
    ).toBe(false);
  });
});

describe('historyQuerySchema', () => {
  it('accepts an empty query and an ordered range', () => {
    expect(historyQuerySchema.safeParse({}).success).toBe(true);
    expect(
      historyQuerySchema.safeParse({ from: '2026-01-01', to: '2026-01-31' })
        .success,
    ).toBe(true);
  });

  it('rejects a range where from is after to', () => {
    expect(
      historyQuerySchema.safeParse({ from: '2026-02-01', to: '2026-01-31' })
        .success,
    ).toBe(false);
  });
});

describe('deleteMissingSchema', () => {
  it('accepts a window with and without kept start dates', () => {
    expect(
      deleteMissingSchema.safeParse({
        startDate: '2026-01-01T00:00:00.000Z',
        endDate: '2026-01-31T00:00:00.000Z',
        keptStartDates: [],
      }).success,
    ).toBe(true);
    expect(
      deleteMissingSchema.safeParse({
        startDate: '2026-01-01T00:00:00.000Z',
        endDate: '2026-01-31T00:00:00.000Z',
        keptStartDates: ['2026-01-02T22:30:00.000Z'],
      }).success,
    ).toBe(true);
  });

  it('rejects a window whose start is after the end', () => {
    expect(
      deleteMissingSchema.safeParse({
        startDate: '2026-02-01T00:00:00.000Z',
        endDate: '2026-01-01T00:00:00.000Z',
        keptStartDates: [],
      }).success,
    ).toBe(false);
  });
});
