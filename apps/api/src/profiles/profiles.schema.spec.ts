import { describe, expect, it } from 'bun:test';

import {
  createProfileSchema,
  preferredUnitsSchema,
  updateProfileSchema,
  updateTimeZoneSchema,
} from './profiles.schema';

const validProfile = {
  weight: 75,
  height: 180,
  age: 30,
  gender: 'male',
  goal: 'maintain',
  activityLevel: 'medium',
};

describe('createProfileSchema', () => {
  it('accepts a valid profile', () => {
    expect(createProfileSchema.safeParse(validProfile).success).toBe(true);
  });

  it('rejects out-of-range weight, height and age', () => {
    expect(
      createProfileSchema.safeParse({ ...validProfile, weight: 19 }).success,
    ).toBe(false);
    expect(
      createProfileSchema.safeParse({ ...validProfile, weight: 401 }).success,
    ).toBe(false);
    expect(
      createProfileSchema.safeParse({ ...validProfile, height: 49 }).success,
    ).toBe(false);
    expect(
      createProfileSchema.safeParse({ ...validProfile, age: 121 }).success,
    ).toBe(false);
  });

  it('rejects an unknown goal enum value', () => {
    expect(
      createProfileSchema.safeParse({ ...validProfile, goal: 'bulk' }).success,
    ).toBe(false);
  });
});

describe('updateProfileSchema', () => {
  it('accepts an empty patch and a partial update', () => {
    expect(updateProfileSchema.safeParse({}).success).toBe(true);
    expect(updateProfileSchema.safeParse({ goal: 'lose' }).success).toBe(true);
  });
});

describe('updateTimeZoneSchema', () => {
  it('accepts a valid IANA time zone', () => {
    expect(
      updateTimeZoneSchema.safeParse({ timeZone: 'Europe/Paris' }).success,
    ).toBe(true);
  });

  it('rejects an invalid time zone and a missing field', () => {
    expect(
      updateTimeZoneSchema.safeParse({ timeZone: 'Mars/Phobos' }).success,
    ).toBe(false);
    expect(updateTimeZoneSchema.safeParse({}).success).toBe(false);
  });
});

describe('preferredUnitsSchema', () => {
  it('applies metric defaults for an empty object', () => {
    const result = preferredUnitsSchema.safeParse({});
    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data).toEqual({
        weight: 'metric',
        volume: 'metric',
        energy: 'kcal',
      });
    }
  });

  it('rejects an invalid unit value', () => {
    expect(preferredUnitsSchema.safeParse({ weight: 'stone' }).success).toBe(
      false,
    );
  });
});
