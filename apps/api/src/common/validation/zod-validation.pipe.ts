import { Injectable } from '@nestjs/common';
import type { PipeTransform } from '@nestjs/common';
import type { ZodSchema } from 'zod';
import { ProblemDetailsException, ProblemType } from '../http/problem-details';
import { fieldErrorsFromIssues } from './field-errors';

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
        fieldErrors: fieldErrorsFromIssues(result.error.issues, value),
      });
    }

    return result.data;
  }
}
