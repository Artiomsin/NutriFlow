import {
  Controller,
  Get,
  Put,
  Body,
  UseGuards,
} from '@nestjs/common';

import { UsersService } from './users.service';
import { updateUserSchema } from './users.schema';
import type { UpdateUserDto } from './users.schema';

import { ZodValidationPipe } from '../common/validation/zod-validation.pipe';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { User } from '../auth/decorators/user.decorator';
import type { AuthPayload } from '../auth/types/auth.types';

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

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