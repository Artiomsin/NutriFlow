import {
  Controller,
  Post,
  Body,
  UseGuards,
  UsePipes,
} from '@nestjs/common';

import { AuthService } from './auth.service';

import {
  registerSchema,
  loginSchema,
  refreshSchema,
  googleLoginSchema,
} from './auth.schema';

import type {
  RegisterDto,
  LoginDto,
  RefreshDto,
  GoogleLoginDto,
} from './auth.schema';

import { ZodValidationPipe } from '../common/validation/zod-validation.pipe';
import { JwtAuthGuard } from './jwt.guard';
import { User } from './decorators/user.decorator';
import type { AuthPayload } from './types/auth.types';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  @UsePipes(new ZodValidationPipe(registerSchema))
  register(@Body() data: RegisterDto) {
    return this.authService.register(data);
  }

  @Post('login')
  @UsePipes(new ZodValidationPipe(loginSchema))
  login(@Body() data: LoginDto) {
    return this.authService.login(data);
  }

  @Post('refresh')
  @UsePipes(new ZodValidationPipe(refreshSchema))
  refresh(@Body() data: RefreshDto) {
    return this.authService.refresh(data.refreshToken);
  }

  @Post('google')
  @UsePipes(new ZodValidationPipe(googleLoginSchema))
  googleLogin(@Body() data: GoogleLoginDto) {
    return this.authService.googleLogin(data);
  }

  @UseGuards(JwtAuthGuard)
  @Post('logout')
  logout(@User() user: AuthPayload) {
    return this.authService.logout(user.userId, user.sessionId);
  }

  @UseGuards(JwtAuthGuard)
  @Post('logout-all')
  logoutAll(@User() user: AuthPayload) {
    return this.authService.logoutAll(user.userId);
  }
}



