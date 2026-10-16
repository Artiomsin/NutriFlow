import { beforeEach, describe, expect, it, mock } from 'bun:test';
import { BadRequestException } from '@nestjs/common';
import sharp from 'sharp';

const send = mock(async () => ({}));
let captured: Record<string, unknown> | undefined;

mock.module('@aws-sdk/client-s3', () => ({
  S3Client: class {
    send = send;
  },
  PutObjectCommand: class {
    constructor(input: Record<string, unknown>) {
      captured = input;
    }
  },
}));

mock.module('../config/env', () => ({
  env: {
    S3_ACCESS_KEY_ID: 'test-key',
    S3_SECRET_ACCESS_KEY: 'test-secret',
    S3_ENDPOINT: 'https://s3.test.local',
    S3_REGION: 'eu-central-1',
    S3_BUCKET: 'test-bucket',
    S3_PUBLIC_URL: 'https://cdn.test.local/',
  },
}));

const { UploadService } = await import('./upload.service');

const createImage = (format: 'png' | 'gif' | 'tiff' = 'png') => {
  const image = sharp({
    create: {
      width: 48,
      height: 48,
      channels: 3,
      background: { r: 1, g: 2, b: 3 },
    },
  });
  if (format === 'gif') return image.gif().toBuffer();
  if (format === 'tiff') return image.tiff().toBuffer();
  return image.png().toBuffer();
};

beforeEach(() => {
  send.mockReset();
  send.mockImplementation(async () => ({}));
  captured = undefined;
});

describe('UploadService.upload', () => {
  it('rejects a non-image buffer', async () => {
    const service = new UploadService();

    expect(service.upload(Buffer.from('nope'))).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });

  it('rejects an unsupported image format', async () => {
    const service = new UploadService();

    expect(service.upload(await createImage('gif'))).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });

  it('uploads a png as webp and returns its public url', async () => {
    const service = new UploadService();

    const url = await service.upload(await createImage('png'));

    expect(url).toMatch(
      /^https:\/\/cdn\.test\.local\/uploads\/[0-9a-f-]{36}\.webp$/,
    );
    expect(send).toHaveBeenCalledTimes(1);
    expect(captured).toMatchObject({
      Bucket: 'test-bucket',
      ContentType: 'image/webp',
    });
    expect(captured?.Key).toMatch(/^uploads\/[0-9a-f-]{36}\.webp$/);

    const stored = await sharp(captured?.Body as Buffer).metadata();
    expect(stored.format).toBe('webp');
    expect(stored.width).toBe(48);
  });

  it('propagates a storage failure', async () => {
    send.mockImplementation(async () => {
      throw new Error('S3 down');
    });
    const service = new UploadService();

    expect(service.upload(await createImage('png'))).rejects.toThrow('S3 down');
  });

  it('fails when storage is not configured', async () => {
    const service = new UploadService();
    (service as unknown as { s3: unknown }).s3 = null;

    expect(service.upload(await createImage('png'))).rejects.toThrow(
      /not configured/,
    );
  });
});
