import {
  Controller,
  Post,
  Body,
  UseGuards,
  UsePipes,
  Req,
} from '@nestjs/common';

import { AuthService } from './auth.service';
import { AuthRateLimitService } from './auth-rate-limit.service';

import {
  registerSchema,
  loginSchema,
  refreshSchema,
  googleLoginSchema,
  appleLoginSchema,
} from './auth.schema';

import type {
  RegisterDto,
  LoginDto,
  RefreshDto,
  GoogleLoginDto,
  AppleLoginDto,
} from './auth.schema';

import { ZodValidationPipe } from '../common/validation/zod-validation.pipe';
import { JwtAuthGuard } from './jwt.guard';
import { User } from './decorators/user.decorator';
import type { AuthPayload } from './types/auth.types';

@Controller('auth')
export class AuthController {
  constructor(
    private readonly authService: AuthService,
    private readonly authRateLimitService: AuthRateLimitService,
  ) {}

  @Post('register')
  @UsePipes(new ZodValidationPipe(registerSchema))
  async register(
    @Body() data: RegisterDto,
    @Req() request: { ip?: string; socket?: { remoteAddress?: string } },
  ) {
    await this.authRateLimitService.checkRegister(this.clientIp(request));
    return this.authService.register(data);
  }

  @Post('login')
  @UsePipes(new ZodValidationPipe(loginSchema))
  async login(
    @Body() data: LoginDto,
    @Req() request: { ip?: string; socket?: { remoteAddress?: string } },
  ) {
    await this.authRateLimitService.checkLogin(this.clientIp(request));
    return this.authService.login(data);
  }

  @Post('refresh')
  @UsePipes(new ZodValidationPipe(refreshSchema))
  async refresh(
    @Body() data: RefreshDto,
    @Req() request: { ip?: string; socket?: { remoteAddress?: string } },
  ) {
    await this.authRateLimitService.checkRefresh(this.clientIp(request));
    return this.authService.refresh(data.refreshToken);
  }

  @Post('google')
  @UsePipes(new ZodValidationPipe(googleLoginSchema))
  async googleLogin(
    @Body() data: GoogleLoginDto,
    @Req() request: { ip?: string; socket?: { remoteAddress?: string } },
  ) {
    await this.authRateLimitService.checkGoogle(this.clientIp(request));
    return this.authService.googleLogin(data);
  }

  @Post('apple')
  @UsePipes(new ZodValidationPipe(appleLoginSchema))
  async appleLogin(
    @Body() data: AppleLoginDto,
    @Req() request: { ip?: string; socket?: { remoteAddress?: string } },
  ) {
    await this.authRateLimitService.checkApple(this.clientIp(request));
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

  private clientIp(request: { ip?: string; socket?: { remoteAddress?: string } }): string {
    return request.ip ?? request.socket?.remoteAddress ?? 'unknown';
  }
}

