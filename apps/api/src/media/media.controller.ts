import {
  Controller,
  Get,
  Header,
  NotFoundException,
  Param,
  ServiceUnavailableException,
  StreamableFile,
} from '@nestjs/common';
import { GetObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { Readable } from 'node:stream';

import { env } from '../config/env';

const FILE_PATTERN = /^[a-z0-9][a-z0-9-]*\.webp$/;

@Controller('media')
export class MediaController {
  private readonly s3: S3Client | null = null;
  private publicBucket = '';

  constructor() {
    if (env.S3_ACCESS_KEY_ID && env.S3_ENDPOINT) {
      this.s3 = new S3Client({
        region: env.S3_REGION,
        endpoint: env.S3_ENDPOINT,
        forcePathStyle: true,
        credentials: {
          accessKeyId: env.S3_ACCESS_KEY_ID,
          secretAccessKey: env.S3_SECRET_ACCESS_KEY,
        },
      });
      this.publicBucket = env.S3_PUBLIC_BUCKET;
    }
  }

  @Get('catalog/:file')
  @Header('Cache-Control', 'public, max-age=604800, immutable')
  async catalog(@Param('file') file: string): Promise<StreamableFile> {
    if (!FILE_PATTERN.test(file)) throw new NotFoundException();
    if (!this.s3) {
      throw new ServiceUnavailableException('Storage is not configured');
    }

    const object = await this.s3
      .send(
        new GetObjectCommand({
          Bucket: this.publicBucket,
          Key: `catalog/${file}`,
        }),
      )
      .catch(() => null);

    if (!object?.Body) throw new NotFoundException();

    return new StreamableFile(object.Body as Readable, {
      type: object.ContentType ?? 'image/webp',
      length: object.ContentLength,
    });
  }
}
