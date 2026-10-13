import { describe, expect, it } from 'bun:test';
import {
  appleLoginSchema,
  googleLoginSchema,
  loginSchema,
  refreshSchema,
  registerSchema,
} from './auth.schema';

describe('registerSchema', () => {
  const valid = {
    email: 'a@b.com',
    password: 'secret1',
    firstName: 'Ann',
    lastName: 'Lee',
  };

  it('accepts a valid payload', () => {
    expect(registerSchema.safeParse(valid).success).toBe(true);
  });

  it('rejects an invalid email', () => {
    expect(registerSchema.safeParse({ ...valid, email: 'nope' }).success).toBe(
      false,
    );
  });

  it('rejects a password shorter than 6', () => {
    expect(
      registerSchema.safeParse({ ...valid, password: '12345' }).success,
    ).toBe(false);
  });

  it('rejects a password longer than 128', () => {
    expect(
      registerSchema.safeParse({ ...valid, password: 'a'.repeat(129) }).success,
    ).toBe(false);
  });

  const badNames: Array<[string, string]> = [
    ['empty', ''],
    ['whitespace only', '   '],
    ['longer than 50', 'a'.repeat(51)],
  ];
  for (const [label, firstName] of badNames) {
    it(`rejects a ${label} first name`, () => {
      expect(registerSchema.safeParse({ ...valid, firstName }).success).toBe(
        false,
      );
    });
  }

  it('trims whitespace around names', () => {
    const out = registerSchema.parse({ ...valid, firstName: '  Ann  ' });
    expect(out.firstName).toBe('Ann');
  });
});

describe('loginSchema', () => {
  it('accepts a valid payload', () => {
    expect(
      loginSchema.safeParse({ email: 'a@b.com', password: 'secret1' }).success,
    ).toBe(true);
  });

  it('rejects a missing password', () => {
    expect(loginSchema.safeParse({ email: 'a@b.com' }).success).toBe(false);
  });
});

describe('refreshSchema', () => {
  it('requires refreshToken', () => {
    expect(refreshSchema.safeParse({}).success).toBe(false);
    expect(refreshSchema.safeParse({ refreshToken: 'x' }).success).toBe(true);
  });
});

describe('googleLoginSchema', () => {
  it('rejects an empty idToken', () => {
    expect(googleLoginSchema.safeParse({ idToken: '' }).success).toBe(false);
  });

  it('rejects an idToken longer than 10000', () => {
    expect(
      googleLoginSchema.safeParse({ idToken: 'a'.repeat(10_001) }).success,
    ).toBe(false);
  });
});

describe('appleLoginSchema', () => {
  it('requires identityToken', () => {
    expect(appleLoginSchema.safeParse({}).success).toBe(false);
  });

  it('accepts optional fields and a nonce up to 512', () => {
    const ok = appleLoginSchema.safeParse({
      identityToken: 't',
      firstName: 'A',
      lastName: 'B',
      nonce: 'a'.repeat(512),
    });
    expect(ok.success).toBe(true);
  });

  it('rejects a nonce longer than 512', () => {
    expect(
      appleLoginSchema.safeParse({ identityToken: 't', nonce: 'a'.repeat(513) })
        .success,
    ).toBe(false);
  });
});
