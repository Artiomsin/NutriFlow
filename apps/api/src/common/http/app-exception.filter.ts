import { Catch, HttpException, HttpStatus, Logger } from '@nestjs/common';
import type { ArgumentsHost, ExceptionFilter } from '@nestjs/common';

@Catch()
export class AppExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(AppExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const response = host.switchToHttp().getResponse<{
      status(code: number): { json(body: unknown): void };
    }>();
    const request = host.switchToHttp().getRequest<{ requestId?: string }>();
    const status =
      exception instanceof HttpException
        ? exception.getStatus()
        : HttpStatus.INTERNAL_SERVER_ERROR;
    const body =
      exception instanceof HttpException
        ? exception.getResponse()
        : { message: 'Internal server error' };

    if (status >= HttpStatus.INTERNAL_SERVER_ERROR) {
      const details = exception instanceof Error ? exception.stack : exception;
      this.logger.error(
        `Unhandled request failure; requestId=${request.requestId ?? 'unknown'}`,
        details,
      );
    }

    response.status(status).json({
      statusCode: status,
      requestId: request.requestId,
      error: body,
    });
  }
}
