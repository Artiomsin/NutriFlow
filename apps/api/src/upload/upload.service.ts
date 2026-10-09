import { BadRequestException, Injectable } from '@nestjs/common';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { env } from '../config/env';
import { randomUUID } from 'node:crypto';
import sharp from 'sharp';

const MAX_INPUT_WIDTH = 6000;
const MAX_INPUT_HEIGHT = 6000;
const MAX_INPUT_PIXELS = 20_000_000;
const OUTPUT_MAX_SIZE = 2048;

@Injectable()
export class UploadService {
  private s3: S3Client | null = null;
  private bucket = '';
  private publicUrl = '';

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
      this.bucket = env.S3_BUCKET;
      this.publicUrl = env.S3_PUBLIC_URL.replace(/\/$/, '');
    }
  }

  async upload(buffer: Buffer, mime: string): Promise<string> {
    const image = sharp(buffer, {
      failOn: 'error',
      limitInputPixels: MAX_INPUT_PIXELS,
    });
    const metadata = await image.metadata().catch(() => null);
    const supportedFormats = new Set(['jpeg', 'png', 'webp', 'heif']);

    if (
      !metadata?.format ||
      !supportedFormats.has(metadata.format) ||
      !metadata.width ||
      !metadata.height
    ) {
      throw new BadRequestException('The uploaded file is not a supported image');
    }

    if (metadata.width > MAX_INPUT_WIDTH || metadata.height > MAX_INPUT_HEIGHT) {
      throw new BadRequestException('Image dimensions must not exceed 6000×6000 pixels');
    }

    const normalizedBuffer = await image
      .rotate()
      .resize({
        width: OUTPUT_MAX_SIZE,
        height: OUTPUT_MAX_SIZE,
        fit: 'inside',
        withoutEnlargement: true,
      })
      .webp({ quality: 85, effort: 4 })
      .toBuffer()
      .catch(() => {
        throw new BadRequestException('The uploaded image could not be processed');
      });

    if (this.s3) {
      const key = `uploads/${randomUUID()}.webp`;
      await this.s3.send(
        new PutObjectCommand({
          Bucket: this.bucket,
          Key: key,
          Body: normalizedBuffer,
          ContentType: 'image/webp',
        }),
      );
      return `${this.publicUrl}/${key}`;
    }

    throw new Error(
      'Upload storage not configured. Set S3_ACCESS_KEY_ID, S3_ENDPOINT, S3_BUCKET, S3_PUBLIC_URL',
    );
  }
}
