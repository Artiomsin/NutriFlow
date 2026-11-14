import { describe, expect, it } from 'bun:test';
import {
  barcodeVariants,
  normalizeGtin,
  parseGtin,
  toGtin14,
  gtinValidationError,
  gtinValidationProblem,
} from './gtin';

describe('GTIN normalization', () => {
  it('normalizes EAN-13 to GTIN-14', () => {
    expect(toGtin14('4006381333931')).toBe('04006381333931');
  });

  it('normalizes UPC-A (12 digits) to GTIN-14', () => {
    expect(toGtin14('012345678905')).toBe('00012345678905');
  });

  it('normalizes EAN-8 to GTIN-14', () => {
    expect(toGtin14('96385074')).toBe('00000096385074');
  });

  it('accepts spaces and dashes', () => {
    expect(toGtin14('400 6381 333931')).toBe('04006381333931');
    expect(toGtin14('400-6381-333931')).toBe('04006381333931');
  });

  it('already canonical GTIN-14 is unchanged', () => {
    expect(toGtin14('04006381333931')).toBe('04006381333931');
  });

  it('rejects invalid check digit', () => {
    expect(toGtin14('1234567890123')).toBeNull();
  });

  it('rejects too short / too long', () => {
    expect(toGtin14('1234567')).toBeNull();
    expect(toGtin14('123456789012345')).toBeNull();
  });

  it('rejects characters other than spaces and dashes', () => {
    expect(toGtin14('400638133393A')).toBeNull();
    expect(gtinValidationProblem('400638133393A')).toEqual({
      detail: 'Barcode must contain only digits, spaces, or dashes.',
      code: 'INVALID_FORMAT',
    });
  });

  it('rejects empty / null', () => {
    expect(toGtin14(null)).toBeNull();
    expect(toGtin14('')).toBeNull();
  });

  it('normalizeGtin returns natural-length digits', () => {
    expect(normalizeGtin('4006381333931')).toBe('4006381333931');
    expect(normalizeGtin('012345678905')).toBe('012345678905');
    expect(normalizeGtin('96385074')).toBe('96385074');
    expect(normalizeGtin('invalid')).toBeNull();
  });

  it('barcodeVariants covers every stored form', () => {
    expect(barcodeVariants('4006381333931')).toEqual([
      '04006381333931',
      '4006381333931',
    ]);
    expect(barcodeVariants('012345678905')).toEqual([
      '00012345678905',
      '0012345678905',
      '012345678905',
    ]);
    expect(barcodeVariants('96385074')).toEqual([
      '00000096385074',
      '0000096385074',
      '000096385074',
      '96385074',
    ]);
    expect(barcodeVariants('invalid')).toEqual([]);
  });

  it('parseGtin identifies format', () => {
    const parsed = parseGtin('4006381333931');
    expect(parsed?.format).toBe('GTIN-13');
    expect(parsed?.valid).toBe(true);

    expect(parseGtin('012345678905')?.format).toBe('GTIN-12');
    expect(parseGtin('96385074')?.format).toBe('GTIN-8');
  });

  it('gtinValidationError messages', () => {
    expect(gtinValidationError(null)).toBe('Barcode cannot be empty.');
    expect(gtinValidationError('123')).toBe(
      'Barcode must contain 8 to 14 digits.',
    );
    expect(gtinValidationError('1234567890123')).toBe(
      'Barcode check digit is invalid.',
    );
  });

  it('gtinValidationProblem returns stable error codes', () => {
    expect(gtinValidationProblem(null)).toEqual({
      detail: 'Barcode cannot be empty.',
      code: 'REQUIRED',
    });
    expect(gtinValidationProblem('123')).toEqual({
      detail: 'Barcode must contain 8 to 14 digits.',
      code: 'INVALID_FORMAT',
    });
    expect(gtinValidationProblem('1234567890123')).toEqual({
      detail: 'Barcode check digit is invalid.',
      code: 'INVALID_VALUE',
    });
  });
});
