import { createParamDecorator} from '@nestjs/common';
import type { AuthPayload } from '../types/auth.types';
import type { ExecutionContext } from '@nestjs/common';
export const User = createParamDecorator(
  (data: keyof AuthPayload | undefined, ctx: ExecutionContext) => {
    const req = ctx.switchToHttp().getRequest();
    const user: AuthPayload = req.user;

    return data ? user?.[data] : user;
  },
);