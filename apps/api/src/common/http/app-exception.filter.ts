import { Catch, HttpException, HttpStatus, Logger } from '@nestjs/common';
import type { ArgumentsHost, ExceptionFilter } from '@nestjs/common';
import {
  defaultProblem,
  detailFromExceptionResponse,
  isProblemDetails,
  type ProblemDetails,
} from './problem-details';

@Catch()
export class AppExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(AppExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const response = host.switchToHttp().getResponse<{
      status(code: number): {
        type(contentType: string): { json(body: unknown): void };
      };
    }>();
    const request = host.switchToHttp().getRequest<{ requestId?: string }>();
    const status =
      exception instanceof HttpException
        ? exception.getStatus()
        : HttpStatus.INTERNAL_SERVER_ERROR;
    const exceptionResponse =
      exception instanceof HttpException ? exception.getResponse() : undefined;

    if (status >= HttpStatus.INTERNAL_SERVER_ERROR) {
      const details = exception instanceof Error ? exception.stack : exception;
      this.logger.error(
        `Unhandled request failure; requestId=${request.requestId ?? 'unknown'}`,
        details,
      );
    }

    const problem = this.problemFor(
      status,
      exceptionResponse,
      request.requestId,
    );

    response.status(status).type('application/problem+json').json(problem);
  }

  private problemFor(
    status: number,
    exceptionResponse: unknown,
    requestId?: string,
  ): ProblemDetails {
    const base = isProblemDetails(exceptionResponse)
      ? exceptionResponse
      : defaultProblem(
          status,
          status < HttpStatus.INTERNAL_SERVER_ERROR
            ? detailFromExceptionResponse(exceptionResponse)
            : undefined,
        );

    return {
      ...base,
      status,
      ...(requestId ? { instance: `urn:uuid:${requestId}` } : {}),
    };
  }
}
