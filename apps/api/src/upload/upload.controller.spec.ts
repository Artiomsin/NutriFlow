import { describe, expect, it, mock } from 'bun:test';
import { Readable } from 'node:stream';
import { GUARDS_METADATA } from '@nestjs/common/constants';

import { JwtAuthGuard } from '../auth/jwt.guard';
import type { AuthPayload } from '../auth/types/auth.types';
import type { UploadService } from './upload.service';
import { UploadController } from './upload.controller';

const user = {
  userId: '00000000-0000-4000-8000-000000000001',
  sessionId: 'session-1',
} as AuthPayload;

describe('UploadController', () => {
  it('requires authentication', () => {
    const guards = Reflect.getMetadata(GUARDS_METADATA, UploadController);
    expect(guards).toContain(JwtAuthGuard);
  });

  it('opens an upload only for the authenticated user', async () => {
    const body = Readable.from(Buffer.from('private-image'));
    const uploadService = {
      openForUser: mock(async () => ({
        body,
        contentType: 'image/webp',
        contentLength: 13,
      })),
    };
    const controller = new UploadController(
      uploadService as unknown as UploadService,
    );

    const response = await controller.getUpload(user, 'upload-1');

    expect(uploadService.openForUser).toHaveBeenCalledWith(
      user.userId,
      'upload-1',
    );
    expect(response.getHeaders()).toEqual({
      type: 'image/webp',
      length: 13,
      disposition: undefined,
    });
  });
});
