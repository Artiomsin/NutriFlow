import { Controller, Post, Body, UseGuards, UsePipes } from '@nestjs/common';

import { AuthService } from './auth.service';

import {
  registerSchema,
  loginSchema,
  refreshSchema,
  changePasswordSchema,
  googleLoginSchema,
  appleLoginSchema,
} from './auth.schema';

import type {
  RegisterDto,
  LoginDto,
  RefreshDto,
  ChangePasswordDto,
  GoogleLoginDto,
  AppleLoginDto,
} from './auth.schema';

import { ZodValidationPipe } from '../common/validation/zod-validation.pipe';
import { JwtAuthGuard } from './jwt.guard';
import { User } from './decorators/user.decorator';
import type { AuthPayload } from './types/auth.types';
import { RateLimit } from '../rate-limit/rate-limit.decorators';
import { env } from '../config/env';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  @RateLimit('auth', env.RATE_LIMIT_AUTH, 900_000)
  @UsePipes(new ZodValidationPipe(registerSchema))
  register(@Body() data: RegisterDto) {
    return this.authService.register(data);
  }

  @Post('login')
  @RateLimit('auth', env.RATE_LIMIT_AUTH, 900_000)
  @UsePipes(new ZodValidationPipe(loginSchema))
  login(@Body() data: LoginDto) {
    return this.authService.login(data);
  }

  @Post('refresh')
  @RateLimit('refresh', env.RATE_LIMIT_REFRESH, 60_000)
  @UsePipes(new ZodValidationPipe(refreshSchema))
  refresh(@Body() data: RefreshDto) {
    return this.authService.refresh(data.refreshToken);
  }

  @UseGuards(JwtAuthGuard)
  @Post('change-password')
  @RateLimit('auth', env.RATE_LIMIT_AUTH, 900_000)
  changePassword(
    @User() user: AuthPayload,
    @Body(new ZodValidationPipe(changePasswordSchema)) data: ChangePasswordDto,
  ) {
    return this.authService.changePassword(user.userId, data);
  }

  @Post('google')
  @RateLimit('auth', env.RATE_LIMIT_AUTH, 900_000)
  @UsePipes(new ZodValidationPipe(googleLoginSchema))
  googleLogin(@Body() data: GoogleLoginDto) {
    return this.authService.googleLogin(data);
  }

  @Post('apple')
  @RateLimit('auth', env.RATE_LIMIT_AUTH, 900_000)
  @UsePipes(new ZodValidationPipe(appleLoginSchema))
  appleLogin(@Body() data: AppleLoginDto) {
    return this.authService.appleLogin(data);
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
