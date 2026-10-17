import { describe, expect, it } from 'bun:test';
import { NotFoundException, RequestMethod } from '@nestjs/common';
import {
  GUARDS_METADATA,
  METHOD_METADATA,
  PATH_METADATA,
} from '@nestjs/common/constants';

import { MediaController } from './media.controller';

describe('MediaController', () => {
  it('exposes the catalog route without an auth guard', () => {
    expect(
      Reflect.getMetadata(GUARDS_METADATA, MediaController),
    ).toBeUndefined();

    expect(Reflect.getMetadata(PATH_METADATA, MediaController)).toBe('media');

    const handler = MediaController.prototype.catalog;
    expect(Reflect.getMetadata(PATH_METADATA, handler)).toBe('catalog/:file');
    expect(Reflect.getMetadata(METHOD_METADATA, handler)).toBe(
      RequestMethod.GET,
    );
  });

  it('rejects file names outside the catalog pattern', async () => {
    const controller = new MediaController();
    await expect(controller.catalog('../secrets.webp')).rejects.toBeInstanceOf(
      NotFoundException,
    );
    await expect(controller.catalog('Not A Slug.webp')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });
});
