import { HttpException, HttpStatus } from '@nestjs/common';
import type { FieldErrorCodeValue } from '../validation/field-errors';

const problemBaseURL = 'https://api.nutriflow.app/problems';

export const ProblemType = {
  invalidRequest: `${problemBaseURL}/invalid-request`,
  validationFailed: `${problemBaseURL}/validation-failed`,
  unauthorized: `${problemBaseURL}/unauthorized`,
  forbidden: `${problemBaseURL}/forbidden`,
  notFound: `${problemBaseURL}/not-found`,
  conflict: `${problemBaseURL}/conflict`,
  requestTimeout: `${problemBaseURL}/request-timeout`,
  rateLimited: `${problemBaseURL}/rate-limited`,
  foodAnalysisQuotaExceeded: `${problemBaseURL}/food-analysis-quota-exceeded`,
  serverError: `${problemBaseURL}/server-error`,
} as const;

export interface FieldProblem {
  field: string;
  code: FieldErrorCodeValue;
}

export interface ProblemDetails {
  type: string;
  title: string;
  status: number;
  detail?: string;
  instance?: string;
  fieldErrors?: FieldProblem[];
}

export class ProblemDetailsException extends HttpException {
  constructor(problem: Omit<ProblemDetails, 'instance'>) {
    super(problem, problem.status);
  }
}

export function isProblemDetails(value: unknown): value is ProblemDetails {
  if (!value || typeof value !== 'object') return false;

  const candidate = value as Partial<ProblemDetails>;
  return (
    typeof candidate.type === 'string' &&
    typeof candidate.title === 'string' &&
    typeof candidate.status === 'number'
  );
}

export function defaultProblem(
  status: number,
  detail?: string,
): ProblemDetails {
  const definition = problemDefinition(status);
  return {
    type: definition.type,
    title: definition.title,
    status,
    ...(detail ? { detail } : {}),
  };
}

function problemDefinition(
  status: number,
): Pick<ProblemDetails, 'type' | 'title'> {
  switch (status) {
    case HttpStatus.BAD_REQUEST:
    case HttpStatus.UNPROCESSABLE_ENTITY:
      return { type: ProblemType.invalidRequest, title: 'Invalid request' };
    case HttpStatus.UNAUTHORIZED:
      return { type: ProblemType.unauthorized, title: 'Unauthorized' };
    case HttpStatus.FORBIDDEN:
      return { type: ProblemType.forbidden, title: 'Forbidden' };
    case HttpStatus.NOT_FOUND:
      return { type: ProblemType.notFound, title: 'Not found' };
    case HttpStatus.CONFLICT:
      return { type: ProblemType.conflict, title: 'Conflict' };
    case HttpStatus.REQUEST_TIMEOUT:
      return { type: ProblemType.requestTimeout, title: 'Request timed out' };
    case HttpStatus.TOO_MANY_REQUESTS:
      return { type: ProblemType.rateLimited, title: 'Too many requests' };
    default:
      return { type: ProblemType.serverError, title: 'Internal server error' };
  }
}

export function detailFromExceptionResponse(
  response: unknown,
): string | undefined {
  if (typeof response === 'string') return response;
  if (!response || typeof response !== 'object') return undefined;

  const message = (response as { message?: unknown }).message;
  if (typeof message === 'string') return message;
  if (Array.isArray(message) && typeof message[0] === 'string') {
    return message[0];
  }
  return undefined;
}
