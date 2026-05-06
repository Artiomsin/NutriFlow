import "reflect-metadata";
import { NestFactory } from "@nestjs/core";
import { AppModule } from "./app.module";
import { ZodValidationPipe } from "./common/validation/zod-validation.pipe";

async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    bufferLogs: true,
  });
  app.enableCors({
    origin: "*",
  });
  app.setGlobalPrefix("api");

  app.useGlobalPipes(new ZodValidationPipe());

  await app.listen(3000);
}

bootstrap();