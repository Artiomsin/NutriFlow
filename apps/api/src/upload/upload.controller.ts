import {
  Controller,
  Get,
  Header,
  Param,
  ParseUUIDPipe,
  StreamableFile,
  UseGuards,
} from '@nestjs/common';

import { JwtAuthGuard } from '../auth/jwt.guard';
import { User } from '../auth/decorators/user.decorator';
import type { AuthPayload } from '../auth/types/auth.types';
import { UploadService } from './upload.service';

@Controller('uploads')
@UseGuards(JwtAuthGuard)
export class UploadController {
  constructor(private readonly uploadService: UploadService) {}

  @Get(':id')
  @Header('Cache-Control', 'private, no-store')
  async getUpload(
    @User() user: AuthPayload,
    @Param('id', new ParseUUIDPipe()) uploadId: string,
  ): Promise<StreamableFile> {
    const upload = await this.uploadService.openForUser(user.userId, uploadId);

    return new StreamableFile(upload.body, {
      type: upload.contentType,
      length: upload.contentLength,
    });
  }
}
