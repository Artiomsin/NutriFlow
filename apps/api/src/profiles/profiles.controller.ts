import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  UseGuards,
  UsePipes,
} from '@nestjs/common';

import { ProfilesService } from './profiles.service';

import {
  createProfileSchema,
  updateProfileSchema,
  updateTimeZoneSchema,
} from './profiles.schema';

import type {
  CreateProfileDto,
  UpdateProfileDto,
  UpdateTimeZoneDto,
} from './profiles.schema';

import { ZodValidationPipe } from '../common/validation/zod-validation.pipe';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { User } from '../auth/decorators/user.decorator';
import type { AuthPayload } from '../auth/types/auth.types';

@Controller('profiles')
export class ProfilesController {
  constructor(private readonly profilesService: ProfilesService) {}

  @UseGuards(JwtAuthGuard)
  @Post()
  create(
    @User() user: AuthPayload,
    @Body(new ZodValidationPipe(createProfileSchema)) data: CreateProfileDto,
  ) {
    return this.profilesService.create({
      ...data,
      userId: user.userId,
    });
  }

  @UseGuards(JwtAuthGuard)
  @Get('me')
  findMe(@User() user: AuthPayload) {
    return this.profilesService.findByUserId(user.userId);
  }

  @UseGuards(JwtAuthGuard)
  @Put('me')
  updateMe(
    @User() user: AuthPayload,
    @Body(new ZodValidationPipe(updateProfileSchema)) data: UpdateProfileDto,
  ) {
    return this.profilesService.updateByUserId(user.userId, data);
  }

  @UseGuards(JwtAuthGuard)
  @Put('me/time-zone')
  updateTimeZone(
    @User() user: AuthPayload,
    @Body(new ZodValidationPipe(updateTimeZoneSchema)) data: UpdateTimeZoneDto,
  ) {
    return this.profilesService.updateTimeZone(user.userId, data.timeZone);
  }

  @UseGuards(JwtAuthGuard)
  @Delete('me')
  deleteMe(@User() user: AuthPayload) {
    return this.profilesService.deleteByUserId(user.userId);
  }
}
