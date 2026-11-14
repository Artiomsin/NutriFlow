/**
 * GTIN (Global Trade Item Number) normalization helpers.
 *
 * A barcode arriving from a scanner can be UPC-A (12 digits), UPC-E (8 digits,
 * zero-suppressed), EAN-8 (8 digits) or EAN-13 (13 digits). Internally we
 * store and compare everything as canonical GTIN-14 (left-padded to 14 digits)
 * so that 0123456789012, 123456789012 and 00123456789012 all resolve to one
 * product.
 */

export type GtinFormat = 'GTIN-8' | 'GTIN-12' | 'GTIN-13' | 'GTIN-14';

interface ParsedGtin {
  readonly digits: string;
  readonly format: GtinFormat;
  readonly valid: boolean;
}

/** Calculates the GTIN check digit for a payload without the last digit. */
function calculateCheckDigit(payload: string): number {
  let sum = 0;
  // Multipliers alternate 3, 1 starting from the rightmost digit of the payload.
  for (let i = payload.length - 1; i >= 0; i--) {
    const multiplier = (payload.length - 1 - i) % 2 === 0 ? 3 : 1;
    sum += Number(payload[i]) * multiplier;
  }
  const mod = sum % 10;
  return mod === 0 ? 0 : 10 - mod;
}

/** Strips scanner formatting that is safe to ignore. */
function onlyDigits(value: string): string {
  return value.replace(/[\s-]/g, '');
}

function hasInvalidCharacters(value: string): boolean {
  return /[^0-9\s-]/.test(value);
}

/**
 * Parses a raw barcode string into a normalized GTIN payload.
 * Returns null when the input cannot be a valid GTIN.
 */
export function parseGtin(value: string | null | undefined): ParsedGtin | null {
  const raw = value ?? '';
  if (hasInvalidCharacters(raw)) {
    return null;
  }

  const digits = onlyDigits(raw);
  if (digits.length === 0) {
    return null;
  }

  // All numeric, length determines the possible format.
  switch (digits.length) {
    case 8:
      return { digits, format: 'GTIN-8', valid: validateCheckDigit(digits) };
    case 12:
      return { digits, format: 'GTIN-12', valid: validateCheckDigit(digits) };
    case 13:
      return { digits, format: 'GTIN-13', valid: validateCheckDigit(digits) };
    case 14:
      return { digits, format: 'GTIN-14', valid: validateCheckDigit(digits) };
    default:
      // Leading zeros may have been dropped by some scanners. Try to restore
      // GTIN-13/GTIN-14 by left-padding when the payload looks like a GTIN
      // without leading zeros.
      if (digits.length > 14 || digits.length < 8) {
        return null;
      }
      return { digits, format: 'GTIN-13', valid: false };
  }
}

function validateCheckDigit(gtin: string): boolean {
  if (gtin.length < 2) return false;
  const payload = gtin.slice(0, -1);
  const expected = calculateCheckDigit(payload);
  return Number(gtin[gtin.length - 1]) === expected;
}

/**
 * Converts any valid GTIN to canonical GTIN-14 (left-padded with zeros).
 * Returns null when the input is not a valid GTIN.
 */
export function toGtin14(value: string | null | undefined): string | null {
  const parsed = parseGtin(value);
  if (!parsed || !parsed.valid) {
    return null;
  }
  return parsed.digits.padStart(14, '0');
}

/**
 * Returns the raw digits of a valid GTIN at its natural length
 * (8 / 12 / 13 / 14). Used for storage in the `barcode` column so that the
 * value looks like the printed barcode.
 */
export function normalizeGtin(value: string | null | undefined): string | null {
  const parsed = parseGtin(value);
  if (!parsed || !parsed.valid) {
    return null;
  }
  return parsed.digits;
}

/**
 * Every stored form of one barcode that a lookup should match.
 *
 * Rows written before GTIN-14 canonicalization may hold an EAN-13 or UPC-A
 * value, while new rows are stored at their natural length. Leading zeros do
 * not change a GTIN check digit, so the shorter standard-length forms are
 * derived from the canonical GTIN-14 and matched together.
 */
export function barcodeVariants(value: string | null | undefined): string[] {
  const gtin14 = toGtin14(value);
  if (!gtin14) {
    return [];
  }

  const variants = new Set<string>([gtin14]);
  for (const length of [13, 12, 8] as const) {
    const offset = 14 - length;
    if (gtin14.startsWith('0'.repeat(offset))) {
      variants.add(gtin14.slice(offset));
    }
  }

  return [...variants];
}

/** Human-readable validation error message. */
export function gtinValidationError(value: string | null | undefined): string {
  return gtinValidationProblem(value).detail;
}

/** Stable, client-facing validation data for an invalid barcode. */
export function gtinValidationProblem(value: string | null | undefined): {
  detail: string;
  code: 'REQUIRED' | 'INVALID_FORMAT' | 'INVALID_VALUE';
} {
  const raw = value ?? '';
  const digits = onlyDigits(raw);
  if (digits.length === 0) {
    return {
      detail: 'Barcode cannot be empty.',
      code: 'REQUIRED',
    };
  }
  if (hasInvalidCharacters(raw)) {
    return {
      detail: 'Barcode must contain only digits, spaces, or dashes.',
      code: 'INVALID_FORMAT',
    };
  }
  if (digits.length < 8 || digits.length > 14) {
    return {
      detail: 'Barcode must contain 8 to 14 digits.',
      code: 'INVALID_FORMAT',
    };
  }
  if (!validateCheckDigit(digits)) {
    return {
      detail: 'Barcode check digit is invalid.',
      code: 'INVALID_VALUE',
    };
  }
  return {
    detail: 'Invalid barcode.',
    code: 'INVALID_VALUE',
  };
}
