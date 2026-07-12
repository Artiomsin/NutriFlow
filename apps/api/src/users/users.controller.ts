import {
  Controller,
  Get,
  Post,
  Put,
  Body,
  Query,
  UseGuards,
} from '@nestjs/common';

import { UsersService } from './users.service';
import { createUserSchema, updateUserSchema } from './users.schema';
import type { CreateUserDto, UpdateUserDto } from './users.schema';

import { ZodValidationPipe } from '../common/validation/zod-validation.pipe';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { User } from '../auth/decorators/user.decorator';
import type { AuthPayload } from '../auth/types/auth.types';

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Post()
  create(
    @Body(new ZodValidationPipe(createUserSchema)) data: CreateUserDto,
  ) {
    return this.usersService.create(data);
  }

  @UseGuards(JwtAuthGuard)
  @Get()
  findAll(
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.usersService.findAll(
      limit ? Math.min(Math.max(parseInt(limit, 10) || 50, 1), 200) : 50,
      offset ? Math.max(parseInt(offset, 10) || 0, 0) : 0,
    );
  }

  @UseGuards(JwtAuthGuard)
  @Get('me')
  me(@User() user: AuthPayload) {
    return this.usersService.findOne(user.userId);
  }

  @UseGuards(JwtAuthGuard)
  @Put('me')
  updateMe(
    @User() user: AuthPayload,
    @Body(new ZodValidationPipe(updateUserSchema)) data: UpdateUserDto,
  ) {
    return this.usersService.updateMe(user.userId, data);
  }
}