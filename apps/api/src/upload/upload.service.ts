import { Injectable } from '@nestjs/common';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { env } from '../config/env';
import { randomUUID } from 'node:crypto';

@Injectable()
export class UploadService {
  private s3: S3Client | null = null;
  private bucket = '';
  private publicUrl = '';

  constructor() {
    if (env.S3_ACCESS_KEY_ID && env.S3_ENDPOINT) {
      this.s3 = new S3Client({
        region: 'us-east-1',
        endpoint: env.S3_ENDPOINT,
        forcePathStyle: true,
        credentials: {
          accessKeyId: env.S3_ACCESS_KEY_ID,
          secretAccessKey: env.S3_SECRET_ACCESS_KEY,
        },
      });
      this.bucket = env.S3_BUCKET;
      this.publicUrl = env.S3_PUBLIC_URL.replace(/\/$/, '');
    }
  }

  async upload(buffer: Buffer, mime: string): Promise<string> {
    if (this.s3) {
      const ext = mime === 'image/png' ? '.png' : '.jpg';
      const key = `uploads/${randomUUID()}${ext}`;
      await this.s3.send(new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: buffer,
        ContentType: mime,
      }));
      return `${this.publicUrl}/${key}`;
    }

    throw new Error('Upload storage not configured. Set S3_ACCESS_KEY_ID, S3_ENDPOINT, S3_BUCKET, S3_PUBLIC_URL');
  }
}
