import type { ZodIssue } from 'zod';

/**
 * Stable, client-facing validation codes.
 *
 * These codes are part of the public API contract.
 * Never expose internal Zod codes or human-readable validation messages.
 */
export const FieldErrorCode = {
  required: 'REQUIRED',
  invalidEmail: 'INVALID_EMAIL',
  invalidFormat: 'INVALID_FORMAT',
  invalidType: 'INVALID_TYPE',
  invalidValue: 'INVALID_VALUE',
  alreadyExists: 'ALREADY_EXISTS',
  tooShort: 'TOO_SHORT',
  tooLong: 'TOO_LONG',
  outOfRange: 'OUT_OF_RANGE',
  unknownField: 'UNKNOWN_FIELD',
} as const;

export type FieldErrorCodeValue =
  (typeof FieldErrorCode)[keyof typeof FieldErrorCode];

export interface FieldError {
  field: string;
  code: FieldErrorCodeValue;
}

/**
 * Converts Zod issues into one stable error per field.
 * The first issue for each field wins.
 */
export function fieldErrorsFromIssues(
  issues: readonly ZodIssue[],
  input: unknown,
): FieldError[] {
  const byField = new Map<string, FieldError>();

  for (const issue of issues) {
    if (issue.code === 'unrecognized_keys') {
      const parentPath = issue.path.map(String).join('.');

      for (const key of issue.keys) {
        const field = parentPath ? `${parentPath}.${key}` : key;

        if (!byField.has(field)) {
          byField.set(field, {
            field,
            code: FieldErrorCode.unknownField,
          });
        }
      }

      continue;
    }

    const field = fieldPath(issue);

    if (byField.has(field)) continue;

    byField.set(field, {
      field,
      code: fieldErrorCode(issue, input),
    });
  }

  return [...byField.values()];
}

export function fieldErrorCode(
  issue: ZodIssue,
  input: unknown,
): FieldErrorCodeValue {
  switch (issue.code) {
    case 'invalid_type':
      return isMissing(input, issue.path)
        ? FieldErrorCode.required
        : FieldErrorCode.invalidType;

    case 'too_small':
      if (issue.origin === 'string') {
        return issue.minimum === 1
          ? FieldErrorCode.required
          : FieldErrorCode.tooShort;
      }

      return FieldErrorCode.outOfRange;

    case 'too_big':
      return issue.origin === 'string'
        ? FieldErrorCode.tooLong
        : FieldErrorCode.outOfRange;

    case 'invalid_format':
      return issue.format === 'email'
        ? FieldErrorCode.invalidEmail
        : FieldErrorCode.invalidFormat;

    case 'unrecognized_keys':
      return FieldErrorCode.unknownField;

    default:
      return FieldErrorCode.invalidValue;
  }
}

export function fieldPath(issue: ZodIssue): string {
  return issue.path.map(String).join('.') || '$form';
}

function isMissing(input: unknown, path: readonly PropertyKey[]): boolean {
  let current = input;

  for (const key of path) {
    if (
      current === null ||
      typeof current !== 'object' ||
      !Object.prototype.hasOwnProperty.call(current, key)
    ) {
      return true;
    }

    current = (current as Record<PropertyKey, unknown>)[key];
  }

  return current === undefined;
}
