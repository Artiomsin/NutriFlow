import { describe, expect, test } from 'bun:test';
import { z } from 'zod';
import {
  FieldErrorCode,
  fieldErrorCode,
  fieldErrorsFromIssues,
  fieldPath,
} from './field-errors';

function issueOf(schema: z.ZodType, value: unknown) {
  const result = schema.safeParse(value);

  if (result.success) {
    throw new Error('Expected a validation failure');
  }

  return result.error.issues[0]!;
}

describe('field error codes', () => {
  test('maps a malformed email to INVALID_EMAIL', () => {
    const schema = z.string().email();
    const value = 'nope';

    expect(fieldErrorCode(issueOf(schema, value), value)).toBe(
      FieldErrorCode.invalidEmail,
    );
  });

  test('maps a missing required value to REQUIRED', () => {
    const schema = z.string();
    const value = undefined;

    expect(fieldErrorCode(issueOf(schema, value), value)).toBe(
      FieldErrorCode.required,
    );
  });

  test('maps an empty string to REQUIRED', () => {
    const schema = z.string().min(1);
    const value = '';

    expect(fieldErrorCode(issueOf(schema, value), value)).toBe(
      FieldErrorCode.required,
    );
  });

  test('distinguishes short and long strings', () => {
    const value = '123';

    expect(fieldErrorCode(issueOf(z.string().min(6), value), value)).toBe(
      FieldErrorCode.tooShort,
    );

    const longValue = '123456';

    expect(
      fieldErrorCode(issueOf(z.string().max(5), longValue), longValue),
    ).toBe(FieldErrorCode.tooLong);
  });

  test('maps numeric bounds to OUT_OF_RANGE', () => {
    expect(fieldErrorCode(issueOf(z.number().min(20), 10), 10)).toBe(
      FieldErrorCode.outOfRange,
    );

    expect(fieldErrorCode(issueOf(z.number().max(400), 500), 500)).toBe(
      FieldErrorCode.outOfRange,
    );
  });

  test('maps wrong types to INVALID_TYPE', () => {
    const value = 'not-a-number';

    expect(fieldErrorCode(issueOf(z.number(), value), value)).toBe(
      FieldErrorCode.invalidType,
    );
  });

  test('maps enums and refinements to INVALID_VALUE', () => {
    const value = 'other';

    expect(
      fieldErrorCode(issueOf(z.enum(['male', 'female']), value), value),
    ).toBe(FieldErrorCode.invalidValue);

    const refined = z.string().refine(() => false, 'nope');

    expect(fieldErrorCode(issueOf(refined, 'a'), 'a')).toBe(
      FieldErrorCode.invalidValue,
    );
  });

  test('maps unknown keys to UNKNOWN_FIELD', () => {
    const schema = z.strictObject({ name: z.string() });
    const value = { name: 'a', extra: true };

    expect(fieldErrorCode(issueOf(schema, value), value)).toBe(
      FieldErrorCode.unknownField,
    );
  });

  test('returns unknown fields with their names', () => {
    const schema = z.strictObject({ name: z.string() });
    const value = { name: 'Artem', extra: true };

    const result = schema.safeParse(value);

    if (result.success) {
      throw new Error('Expected a validation failure');
    }

    expect(fieldErrorsFromIssues(result.error.issues, value)).toEqual([
      { field: 'extra', code: FieldErrorCode.unknownField },
    ]);
  });

  test('uses the dotted path and falls back to $form', () => {
    const schema = z.object({
      profile: z.object({
        weight: z.number().min(20),
      }),
    });

    const value = { profile: { weight: 10 } };
    const issue = issueOf(schema, value);

    expect(fieldPath(issue)).toBe('profile.weight');
    expect(fieldPath({ ...issue, path: [] })).toBe('$form');
  });

  test('maps nested missing fields to REQUIRED', () => {
    const schema = z.object({
      profile: z.object({
        email: z.string(),
      }),
    });

    const value = { profile: {} };
    const result = schema.safeParse(value);

    if (result.success) {
      throw new Error('Expected a validation failure');
    }

    expect(fieldErrorsFromIssues(result.error.issues, value)).toEqual([
      { field: 'profile.email', code: FieldErrorCode.required },
    ]);
  });

  test('returns one error per field and keeps the first issue', () => {
    const schema = z.object({
      email: z.string().email().max(3),
      password: z.string().min(6),
    });

    const value = {
      email: 'not-an-email',
      password: '123',
    };

    const result = schema.safeParse(value);

    if (result.success) {
      throw new Error('Expected a validation failure');
    }

    expect(fieldErrorsFromIssues(result.error.issues, value)).toEqual([
      { field: 'email', code: FieldErrorCode.invalidEmail },
      { field: 'password', code: FieldErrorCode.tooShort },
    ]);
  });
});
