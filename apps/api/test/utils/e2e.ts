import { randomUUID } from 'node:crypto';
import { Test } from '@nestjs/testing';
import type { INestApplication } from '@nestjs/common';

import { AppModule } from '../../src/app.module';
import { AppExceptionFilter } from '../../src/common/http/app-exception.filter';
import { DB, DB_POOL } from '../../src/db/db.module';
import { isolate } from './app';

/**
 * Boots the real AppModule against an isolated transaction, mirroring the
 * global setup from src/main.ts (api prefix, request-id middleware and
 * exception filter). Ready for supertest(app.getHttpServer()).
 */
export async function createE2eApp(tx: unknown): Promise<INestApplication> {
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
    .overrideProvider(DB_POOL)
    .useValue({ end: async () => {} })
    .overrideProvider(DB)
    .useValue(isolate(tx))
    .compile();

  const app = moduleRef.createNestApplication({ logger: false });
  app.setGlobalPrefix('api');
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
  await app.init();

  return app;
}
