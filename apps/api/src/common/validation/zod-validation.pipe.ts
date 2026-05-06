import {
  Injectable,
  BadRequestException,
} from '@nestjs/common';

import type {  PipeTransform, ArgumentMetadata } from '@nestjs/common';
import type { ZodSchema } from 'zod';

@Injectable()
export class ZodValidationPipe implements PipeTransform {
  transform(value: unknown, metadata: ArgumentMetadata) {
    const { metatype } = metadata;

    if (!metatype || !(metatype as any).schema) {
      return value;
    }

    const schema: ZodSchema = (metatype as any).schema;

    const result = schema.safeParse(value);

    if (!result.success) {
      throw new BadRequestException({
        message: 'Validation failed',
        errors: result.error.flatten().fieldErrors,
      });
    }

    return result.data;
  }
}