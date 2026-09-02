import { identity } from 'rxjs';
import { z } from 'zod';


export const registerSchema = z.object({
  email: z.string().email(),
  password: z.string().min(6),
  firstName: z.string(),
  lastName: z.string(),
});

export const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(6),
});

export const refreshSchema = z.object({
  refreshToken: z.string(),
});

export const googleLoginSchema = z.object({
  idToken: z.string(),
});

export const appleLoginSchema = z.object({
  identityToken: z.string().min(1),
  firstName: z.string().optional(),
  lastName: z.string().optional(),
});



export type RegisterDto = z.infer<typeof registerSchema>;
export type LoginDto = z.infer<typeof loginSchema>;
export type RefreshDto = z.infer<typeof refreshSchema>;
export type GoogleLoginDto = z.infer<typeof googleLoginSchema>;
export type AppleLoginDto = z.infer<typeof appleLoginSchema>;
