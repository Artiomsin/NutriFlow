import {
  Catch,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import type { ArgumentsHost, ExceptionFilter } from '@nestjs/common';

@Catch()
export class AppExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    const response = host.switchToHttp().getResponse<{
      status(code: number): { json(body: unknown): void };
    }>();
    const request = host.switchToHttp().getRequest<{ requestId?: string }>();
    const status = exception instanceof HttpException
      ? exception.getStatus()
      : HttpStatus.INTERNAL_SERVER_ERROR;
    const body = exception instanceof HttpException
      ? exception.getResponse()
      : { message: 'Internal server error' };

    response.status(status).json({
      statusCode: status,
      requestId: request.requestId,
      error: body,
    });
  }
}
