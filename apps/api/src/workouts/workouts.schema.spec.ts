import { describe, expect, it } from 'bun:test';

import {
  deleteMissingSchema,
  historyQuerySchema,
  syncWorkoutSchema,
  syncWorkoutsSchema,
} from './workouts.schema';

const validWorkout = {
  healthKitWorkoutId: 'HK-0001',
  type: 'running',
  startDate: '2026-01-01T10:00:00.000Z',
  endDate: '2026-01-01T10:45:00.000Z',
  localDate: '2026-01-01',
  durationSeconds: 2_700,
};

describe('syncWorkoutSchema', () => {
  it('accepts a minimal workout and a fully populated one', () => {
    expect(syncWorkoutSchema.safeParse(validWorkout).success).toBe(true);
    expect(
      syncWorkoutSchema.safeParse({
        ...validWorkout,
        caloriesBurned: 320,
        distanceMeters: 5_200,
        heartRateAvg: 148,
        heartRateMax: 172,
        heartRateMin: 110,
        avgSpeedMps: 1.93,
        maxSpeedMps: 4.1,
        avgCadence: 172,
        maxCadence: 186,
        avgPowerWatts: 210,
        maxPowerWatts: 480,
        elevationGainMeters: 35,
        steps: 4_800,
        indoor: false,
        details: { source: 'HealthKit' },
      }).success,
    ).toBe(true);
  });

  it('accepts null for the nullable metrics', () => {
    expect(
      syncWorkoutSchema.safeParse({
        ...validWorkout,
        heartRateAvg: null,
        avgSpeedMps: null,
        steps: null,
        indoor: null,
      }).success,
    ).toBe(true);
  });

  it('rejects null for the non-nullable optional metrics', () => {
    expect(
      syncWorkoutSchema.safeParse({ ...validWorkout, caloriesBurned: null })
        .success,
    ).toBe(false);
    expect(
      syncWorkoutSchema.safeParse({ ...validWorkout, distanceMeters: null })
        .success,
    ).toBe(false);
  });

  it('rejects a blank type or an oversized workout id', () => {
    expect(
      syncWorkoutSchema.safeParse({ ...validWorkout, type: '' }).success,
    ).toBe(false);
    expect(
      syncWorkoutSchema.safeParse({
        ...validWorkout,
        healthKitWorkoutId: 'x'.repeat(65),
      }).success,
    ).toBe(false);
  });

  it('rejects a duration outside 0..86400', () => {
    expect(
      syncWorkoutSchema.safeParse({
        ...validWorkout,
        durationSeconds: -1,
      }).success,
    ).toBe(false);
    expect(
      syncWorkoutSchema.safeParse({
        ...validWorkout,
        durationSeconds: 86_400,
      }).success,
    ).toBe(true);
    expect(
      syncWorkoutSchema.safeParse({
        ...validWorkout,
        durationSeconds: 86_401,
      }).success,
    ).toBe(false);
  });

  it('rejects an end before or equal to the start', () => {
    expect(
      syncWorkoutSchema.safeParse({
        ...validWorkout,
        endDate: '2026-01-01T10:00:00.000Z',
      }).success,
    ).toBe(false);
    expect(
      syncWorkoutSchema.safeParse({
        ...validWorkout,
        endDate: '2026-01-01T09:00:00.000Z',
      }).success,
    ).toBe(false);
  });

  it('rejects negative metrics and out-of-range heart rates', () => {
    expect(
      syncWorkoutSchema.safeParse({ ...validWorkout, caloriesBurned: -1 })
        .success,
    ).toBe(false);
    expect(
      syncWorkoutSchema.safeParse({ ...validWorkout, distanceMeters: -1 })
        .success,
    ).toBe(false);
    expect(
      syncWorkoutSchema.safeParse({ ...validWorkout, heartRateAvg: 301 })
        .success,
    ).toBe(false);
    expect(
      syncWorkoutSchema.safeParse({ ...validWorkout, heartRateMax: 301 })
        .success,
    ).toBe(false);
    expect(
      syncWorkoutSchema.safeParse({ ...validWorkout, steps: -1 }).success,
    ).toBe(false);
  });
});

describe('syncWorkoutsSchema', () => {
  it('accepts a non-empty list and rejects an empty one', () => {
    expect(
      syncWorkoutsSchema.safeParse({ workouts: [validWorkout] }).success,
    ).toBe(true);
    expect(syncWorkoutsSchema.safeParse({ workouts: [] }).success).toBe(false);
  });
});

describe('historyQuerySchema', () => {
  it('accepts an empty query and rejects a reversed range', () => {
    expect(historyQuerySchema.safeParse({}).success).toBe(true);
    expect(
      historyQuerySchema.safeParse({ from: '2026-02-01', to: '2026-01-31' })
        .success,
    ).toBe(false);
  });
});

describe('deleteMissingSchema', () => {
  it('accepts a window with and without kept workout ids', () => {
    expect(
      deleteMissingSchema.safeParse({
        startDate: '2026-01-01T00:00:00.000Z',
        endDate: '2026-01-31T00:00:00.000Z',
        healthKitWorkoutIds: [],
      }).success,
    ).toBe(true);
    expect(
      deleteMissingSchema.safeParse({
        startDate: '2026-01-01T00:00:00.000Z',
        endDate: '2026-01-31T00:00:00.000Z',
        healthKitWorkoutIds: ['HK-0001'],
      }).success,
    ).toBe(true);
  });

  it('rejects a window where the start is after the end', () => {
    expect(
      deleteMissingSchema.safeParse({
        startDate: '2026-02-01T00:00:00.000Z',
        endDate: '2026-01-31T00:00:00.000Z',
        healthKitWorkoutIds: [],
      }).success,
    ).toBe(false);
  });
});
