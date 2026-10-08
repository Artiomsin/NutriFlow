import { z } from 'zod';

const passwordSchema = z.string().min(6).max(128);
const nameSchema = z.string().trim().min(1).max(50);

export const createUserSchema = z.object({
  email: z.string().email().max(120),
  password: passwordSchema,
  firstName: nameSchema.optional(),
  lastName: nameSchema.optional(),
});

export const updateUserSchema = z.object({
  email: z.string().email().max(120).optional(),
  password: passwordSchema.optional(),
  firstName: nameSchema.optional(),
  lastName: nameSchema.optional(),
});

export type CreateUserDto = z.infer<typeof createUserSchema>;
export type UpdateUserDto = z.infer<typeof updateUserSchema>;
