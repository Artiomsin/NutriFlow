import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { randomUUID } from 'node:crypto';
import { AppExceptionFilter } from './common/http/app-exception.filter';
import { env } from './config/env';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    bufferLogs: true,
  });
  // Render forwards requests through its proxy; this restores the client IP
  // used by the rate-limit guard instead of treating every client as one IP.
  app.getHttpAdapter().getInstance().set('trust proxy', env.TRUST_PROXY);
  app.enableCors({ origin: '*' });
  app.setGlobalPrefix('api');
  app.enableShutdownHooks();
  app.use(
    (
      request: { requestId?: string },
      response: { setHeader(name: string, value: string): void },
      next: () => void,
    ) => {
      const requestId = randomUUID();
      request.requestId = requestId;
      response.setHeader('X-Request-ID', requestId);
      next();
    },
  );
  app.useGlobalFilters(new AppExceptionFilter());

  await app.listen(Number(process.env.PORT) || 3000, '0.0.0.0');
}
void bootstrap();
