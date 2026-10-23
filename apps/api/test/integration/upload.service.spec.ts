import { afterAll, beforeAll, describe, expect, it } from 'bun:test';
import { randomUUID } from 'node:crypto';
import {
  CreateBucketCommand,
  DeleteObjectCommand,
  HeadBucketCommand,
  HeadObjectCommand,
  ListObjectsV2Command,
  S3Client,
} from '@aws-sdk/client-s3';

import { env } from '../../src/config/env';
import { UploadService } from '../../src/upload/upload.service';
import { hasAllFixtures, readFixture } from '../utils/fixtures';

const s3Configured = Boolean(env.S3_ACCESS_KEY_ID && env.S3_ENDPOINT);
const shouldRun = s3Configured && hasAllFixtures();
const run = shouldRun ? describe : describe.skip;

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
const userId = '00000000-0000-4000-8000-000000000001';
const db = {
  transaction: async (
    callback: (tx: {
      execute: () => Promise<void>;
      select: () => {
        from: () => {
          where: () => { limit: () => Promise<Array<{ id: string }>> };
        };
      };
      insert: () => {
        values: () => { returning: () => Promise<Array<{ id: string }>> };
      };
    }) => Promise<unknown>,
  ) =>
    callback({
      execute: async () => undefined,
      select: () => ({
        from: () => ({
          where: () => ({ limit: async () => [{ id: userId }] }),
        }),
      }),
      insert: () => ({
        values: () => ({
          returning: async () => [{ id: randomUUID() }],
        }),
      }),
    }),
};

const head = (key: string) =>
  client.send(
    new HeadObjectCommand({ Bucket: env.S3_PRIVATE_BUCKET, Key: key }),
  );

const remove = (key: string) =>
  client.send(
    new DeleteObjectCommand({ Bucket: env.S3_PRIVATE_BUCKET, Key: key }),
  );

const listKeys = async () => {
  const result = await client.send(
    new ListObjectsV2Command({
      Bucket: env.S3_PRIVATE_BUCKET,
      Prefix: `uploads/${userId}/`,
    }),
  );
  return new Set(
    result.Contents?.flatMap((object) => (object.Key ? [object.Key] : [])) ??
      [],
  );
};

beforeAll(async () => {
  if (!s3Configured) return;
  try {
    await client.send(new HeadBucketCommand({ Bucket: env.S3_PRIVATE_BUCKET }));
  } catch {
    await client.send(
      new CreateBucketCommand({ Bucket: env.S3_PRIVATE_BUCKET }),
    );
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
      const service = new UploadService(db as never);

      const before = await listKeys();
      const upload = await service.upload(userId, readFixture(name).buffer);
      expect(upload.id).toMatch(/^[0-9a-f-]{36}$/);

      const after = await listKeys();
      const key = [...after].find((candidate) => !before.has(candidate));
      expect(key).toMatch(
        new RegExp(`^uploads/${userId}/[0-9a-f-]{36}\\.webp$`),
      );
      if (!key) throw new Error('Uploaded object was not found');
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
