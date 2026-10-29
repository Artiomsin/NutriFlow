import { Injectable } from '@nestjs/common';
import type { PipeTransform } from '@nestjs/common';
import type { ZodSchema } from 'zod';
import { ProblemDetailsException, ProblemType } from '../http/problem-details';

@Injectable()
export class ZodValidationPipe implements PipeTransform {
  constructor(private schema: ZodSchema) {}

  transform(value: unknown) {
    const result = this.schema.safeParse(value);

    if (!result.success) {
      throw new ProblemDetailsException({
        type: ProblemType.validationFailed,
        title: 'Validation failed',
        status: 400,
        detail: 'One or more fields are invalid.',
        fieldErrors: result.error.issues.map((issue) => ({
          field: issue.path.map(String).join('.') || '$form',
          code: issue.code.toUpperCase(),
        })),
      });
    }

    return result.data;
  }
}
