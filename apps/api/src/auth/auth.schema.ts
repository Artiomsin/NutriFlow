import { z } from 'zod';

const passwordSchema = z.string().min(6).max(128);
const nameSchema = z.string().trim().min(1).max(50);


export const registerSchema = z.object({
  email: z.string().email().max(120),
  password: passwordSchema,
  firstName: nameSchema,
  lastName: nameSchema,
});

export const loginSchema = z.object({
  email: z.string().email().max(120),
  password: passwordSchema,
});

export const refreshSchema = z.object({
  refreshToken: z.string(),
});

export const googleLoginSchema = z.object({
  idToken: z.string().min(1).max(10_000),
});

export const appleLoginSchema = z.object({
  identityToken: z.string().min(1),
  firstName: nameSchema.optional(),
  lastName: nameSchema.optional(),
  nonce: z.string().min(1).max(512).optional(),
});



export type RegisterDto = z.infer<typeof registerSchema>;
export type LoginDto = z.infer<typeof loginSchema>;
export type RefreshDto = z.infer<typeof refreshSchema>;
export type GoogleLoginDto = z.infer<typeof googleLoginSchema>;
export type AppleLoginDto = z.infer<typeof appleLoginSchema>;
