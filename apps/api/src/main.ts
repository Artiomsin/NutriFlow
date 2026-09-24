import "reflect-metadata";
import { NestFactory } from "@nestjs/core";
import { AppModule } from "./app.module";
import { randomUUID } from 'node:crypto';
import { AppExceptionFilter } from './common/http/app-exception.filter';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    bufferLogs: true,
  });
  app.enableCors({ origin: "*" });
  app.setGlobalPrefix("api");
  app.enableShutdownHooks();
  app.use((request: { requestId?: string }, response: { setHeader(name: string, value: string): void }, next: () => void) => {
    const requestId = randomUUID();
    request.requestId = requestId;
    response.setHeader('X-Request-ID', requestId);
    next();
  });
  app.useGlobalFilters(new AppExceptionFilter());

  await app.listen(3000, '0.0.0.0');
}
bootstrap();
