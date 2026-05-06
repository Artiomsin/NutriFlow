import type { ZodSchema, z } from 'zod';

export function createZodDto<T extends ZodSchema>(schema: T) {
  class ZodDto {
    static schema = schema;
  }

  return ZodDto as unknown as {
    new (): z.infer<T>;
    schema: T;
  };
}