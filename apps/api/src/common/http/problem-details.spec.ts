import { describe, expect, test } from 'bun:test';
import { HttpStatus } from '@nestjs/common';
import {
  ProblemDetailsException,
  ProblemType,
  defaultProblem,
  detailFromExceptionResponse,
} from './problem-details';

describe('problem details', () => {
  test('maps standard HTTP statuses to stable problem types', () => {
    expect(defaultProblem(HttpStatus.NOT_FOUND)).toEqual({
      type: ProblemType.notFound,
      title: 'Not found',
      status: HttpStatus.NOT_FOUND,
    });
  });

  test('maps 503 to service unavailable', () => {
    expect(defaultProblem(HttpStatus.SERVICE_UNAVAILABLE)).toEqual({
      type: ProblemType.serviceUnavailable,
      title: 'Service unavailable',
      status: HttpStatus.SERVICE_UNAVAILABLE,
    });
  });

  test('never exposes a 5xx exception message as problem detail', () => {
    expect(defaultProblem(HttpStatus.INTERNAL_SERVER_ERROR)).toEqual({
      type: ProblemType.serverError,
      title: 'Internal server error',
      status: HttpStatus.INTERNAL_SERVER_ERROR,
    });
  });

  test('keeps a client-safe message from a standard exception response', () => {
    expect(detailFromExceptionResponse('Email already registered')).toBe(
      'Email already registered',
    );
  });

  test('preserves an explicitly declared domain problem', () => {
    const exception = new ProblemDetailsException({
      type: ProblemType.foodAnalysisQuotaExceeded,
      title: 'Food analysis quota exceeded',
      status: HttpStatus.TOO_MANY_REQUESTS,
      detail: 'A new analysis slot will become available later.',
    });

    expect(exception.getStatus()).toBe(HttpStatus.TOO_MANY_REQUESTS);
    expect(exception.getResponse()).toEqual({
      type: ProblemType.foodAnalysisQuotaExceeded,
      title: 'Food analysis quota exceeded',
      status: HttpStatus.TOO_MANY_REQUESTS,
      detail: 'A new analysis slot will become available later.',
    });
  });
});
