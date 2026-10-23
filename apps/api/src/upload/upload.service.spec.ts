import { describe, expect, it, mock } from 'bun:test';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { Readable } from 'node:stream';
import sharp from 'sharp';
import type { GetObjectCommand, PutObjectCommand } from '@aws-sdk/client-s3';
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
      insert: () => {
        values: () => { returning: () => Promise<Array<{ id: string }>> };
      };
    }) => Promise<unknown>,
  ) =>
    callback({
      execute: async () => undefined,
      select: () => ({
        from: () => ({
          where: () => ({ limit: async () => [{ id: USER_ID }] }),
        }),
      }),
      insert: () => ({
        values: () => ({ returning: async () => [{ id: 'upload-1' }] }),
      }),
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

type Send = (command: PutObjectCommand | GetObjectCommand) => Promise<unknown>;

function setup() {
  const service = new UploadService(db as never);
  const sent: PutObjectCommand[] = [];
  const send = mock(async (command: PutObjectCommand) => {
    sent.push(command);
    return {};
  });

  const internal = service as unknown as {
    s3: { send: Send } | null;
    privateBucket: string;
  };
  internal.s3 = { send };
  internal.privateBucket = 'test-bucket';

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

  it('uploads a png as webp and returns its private upload id', async () => {
    const { service, send, sent } = setup();

    const upload = await service.upload(USER_ID, await createImage('png'));

    expect(upload).toEqual({ id: 'upload-1' });
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

describe('UploadService.openForUser', () => {
  it('does not expose an upload that belongs to another user', async () => {
    const privateDb = {
      select: () => ({
        from: () => ({
          where: () => ({ limit: async () => [] }),
        }),
      }),
    };
    const service = new UploadService(privateDb as never);
    (service as unknown as { s3: { send: Send } }).s3 = {
      send: mock(async () => ({})),
    };

    await expect(
      service.openForUser('another-user', 'upload-1'),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('streams an upload only after the owner lookup succeeds', async () => {
    const body = Readable.from(Buffer.from('private-image'));
    const privateDb = {
      select: () => ({
        from: () => ({
          where: () => ({
            limit: async () => [
              {
                objectKey: 'uploads/user-1/image.webp',
                contentType: 'image/webp',
              },
            ],
          }),
        }),
      }),
    };
    const service = new UploadService(privateDb as never);
    (service as unknown as { s3: { send: Send }; privateBucket: string }).s3 = {
      send: mock(async () => ({
        Body: body,
        ContentType: 'image/webp',
        ContentLength: 13,
      })),
    };
    (service as unknown as { privateBucket: string }).privateBucket =
      'private-bucket';

    const upload = await service.openForUser('user-1', 'upload-1');

    expect(upload).toEqual({
      body,
      contentType: 'image/webp',
      contentLength: 13,
    });
  });
});
