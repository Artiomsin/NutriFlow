import { describe, expect, it, mock } from 'bun:test';
import { BadRequestException } from '@nestjs/common';
import sharp from 'sharp';
import type { PutObjectCommand } from '@aws-sdk/client-s3';
import { UploadService } from './upload.service';

const USER_ID = '00000000-0000-4000-8000-000000000001';

const db = {
  transaction: async (
    callback: (tx: {
      execute: () => Promise<void>;
      select: () => {
        from: () => {
          where: () => { limit: () => Promise<Array<{ id: string }>> };
        };
      };
      insert: () => { values: () => Promise<void> };
    }) => Promise<unknown>,
  ) =>
    callback({
      execute: async () => undefined,
      select: () => ({
        from: () => ({
          where: () => ({ limit: async () => [{ id: USER_ID }] }),
        }),
      }),
      insert: () => ({ values: async () => undefined }),
    }),
};

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

type Send = (command: PutObjectCommand) => Promise<unknown>;

function setup() {
  const service = new UploadService(db as never);
  const sent: PutObjectCommand[] = [];
  const send = mock(async (command: PutObjectCommand) => {
    sent.push(command);
    return {};
  });

  const internal = service as unknown as {
    s3: { send: Send } | null;
    bucket: string;
    publicUrl: string;
  };
  internal.s3 = { send };
  internal.bucket = 'test-bucket';
  internal.publicUrl = 'https://cdn.test.local';

  return { service, send, sent };
}

describe('UploadService.upload', () => {
  it('rejects a non-image buffer', async () => {
    const { service } = setup();

    expect(service.upload(USER_ID, Buffer.from('nope'))).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });

  it('rejects an unsupported image format', async () => {
    const { service } = setup();

    expect(
      service.upload(USER_ID, await createImage('gif')),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('uploads a png as webp and returns its public url', async () => {
    const { service, send, sent } = setup();

    const url = await service.upload(USER_ID, await createImage('png'));

    expect(url).toMatch(
      new RegExp(
        `^https://cdn\\.test\\.local/uploads/${USER_ID}/[0-9a-f-]{36}\\.webp$`,
      ),
    );
    expect(send).toHaveBeenCalledTimes(1);
    const input = sent[0]?.input;
    expect(input).toMatchObject({
      Bucket: 'test-bucket',
      ContentType: 'image/webp',
    });
    expect(input?.Key).toMatch(
      new RegExp(`^uploads/${USER_ID}/[0-9a-f-]{36}\\.webp$`),
    );

    const stored = await sharp(input?.Body as Buffer).metadata();
    expect(stored.format).toBe('webp');
    expect(stored.width).toBe(48);
  });

  it('propagates a storage failure', async () => {
    const { service, send } = setup();
    send.mockImplementation(async () => {
      throw new Error('S3 down');
    });

    expect(service.upload(USER_ID, await createImage('png'))).rejects.toThrow(
      'S3 down',
    );
  });

  it('fails when storage is not configured', async () => {
    const { service } = setup();
    (service as unknown as { s3: unknown }).s3 = null;

    expect(service.upload(USER_ID, await createImage('png'))).rejects.toThrow(
      /not configured/,
    );
  });
});
