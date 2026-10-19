import { afterAll, beforeAll, describe, expect, it } from 'bun:test';
import {
  CreateBucketCommand,
  DeleteObjectCommand,
  HeadBucketCommand,
  HeadObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';

import { env } from '../../src/config/env';
import { UploadService } from '../../src/upload/upload.service';
import { hasAllFixtures, readFixture } from '../utils/fixtures';

const s3Configured = Boolean(env.S3_ACCESS_KEY_ID && env.S3_ENDPOINT);
const shouldRun = s3Configured && hasAllFixtures();
const run = shouldRun ? describe : describe.skip;

const publicUrlPrefix = `${env.S3_PUBLIC_URL.replace(/\/$/, '')}/`;

const client = new S3Client({
  region: env.S3_REGION,
  endpoint: env.S3_ENDPOINT,
  forcePathStyle: true,
  credentials: {
    accessKeyId: env.S3_ACCESS_KEY_ID,
    secretAccessKey: env.S3_SECRET_ACCESS_KEY,
  },
});

const uploadedKeys: string[] = [];

const keyFromUrl = (url: string) => url.slice(publicUrlPrefix.length);

const head = (key: string) =>
  client.send(new HeadObjectCommand({ Bucket: env.S3_BUCKET, Key: key }));

const remove = (key: string) =>
  client.send(new DeleteObjectCommand({ Bucket: env.S3_BUCKET, Key: key }));

beforeAll(async () => {
  if (!s3Configured) return;
  try {
    await client.send(new HeadBucketCommand({ Bucket: env.S3_BUCKET }));
  } catch {
    await client.send(new CreateBucketCommand({ Bucket: env.S3_BUCKET }));
  }
});

afterAll(async () => {
  if (!s3Configured) return;
  await Promise.all(
    uploadedKeys.map((key) => remove(key).catch(() => undefined)),
  );
});

run('UploadService against real object storage', () => {
  it.each(['meal-single', 'drink-water'] as const)(
    'uploads %s, stores it as webp, then deletes it',
    async (name) => {
      const service = new UploadService();

      const url = await service.upload(readFixture(name).buffer);
      expect(url.startsWith(publicUrlPrefix)).toBe(true);
      expect(url).toMatch(/\/uploads\/[0-9a-f-]{36}\.webp$/);

      const key = keyFromUrl(url);
      uploadedKeys.push(key);

      const stored = await head(key);
      expect(stored.ContentType).toBe('image/webp');
      expect(stored.ContentLength).toBeGreaterThan(0);

      await remove(key);
      expect(head(key)).rejects.toThrow();
    },
    30_000,
  );
});
