import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  UsePipes,
  ParseUUIDPipe,
} from '@nestjs/common';

import { ProfilesService } from './profiles.service';

import { createProfileSchema, updateProfileSchema } from './profiles.schema';

import type { CreateProfileDto, UpdateProfileDto } from './profiles.schema';

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
  @Get()
  findAll(
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.profilesService.findAll(
      limit ? Math.min(Math.max(parseInt(limit, 10) || 50, 1), 200) : 50,
      offset ? Math.max(parseInt(offset, 10) || 0, 0) : 0,
    );
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
  @Delete('me')
  deleteMe(@User() user: AuthPayload) {
    return this.profilesService.deleteByUserId(user.userId);
  }
}