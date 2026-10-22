import { describe, expect, it, mock } from 'bun:test';
import { HttpStatus } from '@nestjs/common';
import { HTTP_CODE_METADATA } from '@nestjs/common/constants';

import type { AuthPayload } from '../auth/types/auth.types';
import { UsersController } from './users.controller';
import type { UsersService } from './users.service';

const user = { userId: 'user-1', sessionId: 'session-1' } as AuthPayload;

describe('UsersController', () => {
  it('deletes only the authenticated user and returns no content', async () => {
    const usersService = { deleteMe: mock(async () => undefined) };
    const controller = new UsersController(
      usersService as unknown as UsersService,
    );

    await expect(controller.deleteMe(user)).resolves.toBeUndefined();
    expect(usersService.deleteMe).toHaveBeenCalledWith('user-1');
    expect(Reflect.getMetadata(HTTP_CODE_METADATA, controller.deleteMe)).toBe(
      HttpStatus.NO_CONTENT,
    );
  });
});
