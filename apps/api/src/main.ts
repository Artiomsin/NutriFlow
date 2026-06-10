import "reflect-metadata";
import { NestFactory } from "@nestjs/core";
import { AppModule } from "./app.module";
import { readFileSync } from "fs";

async function bootstrap() {
  const httpsOptions = {
    key: readFileSync("./certs/key.pem"),
    cert: readFileSync("./certs/cert.pem"),
  };

  const app = await NestFactory.create(AppModule, {
    httpsOptions,
    bufferLogs: true,
  });
  app.enableCors({ origin: "*" });
  app.setGlobalPrefix("api");

  await app.listen(3000, '0.0.0.0');
}
bootstrap();