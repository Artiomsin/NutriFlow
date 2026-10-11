import {
  Inject,
  Injectable,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';

import { eq } from 'drizzle-orm';
import * as bcrypt from 'bcrypt';

import type { Db } from '../db/db';
import { DB } from '../db/db.module';
import { users } from '../db/schema/users';

import type { UpdateUserDto } from './users.schema';

@Injectable()
export class UsersService {
  constructor(@Inject(DB) private readonly db: Db) {}

  private toSafeUser(user: typeof users.$inferSelect) {
    return {
      id: user.id,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      avatarUrl: user.avatarUrl,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    };
  }

  async findOne(id: string) {
    const user = await this.db
      .select()
      .from(users)
      .where(eq(users.id, id))
      .limit(1)
      .then((r) => r[0]);

    if (!user) {
      throw new NotFoundException('User not found');
    }

    return this.toSafeUser(user);
  }

  async updateMe(userId: string, data: UpdateUserDto) {
    const existing = await this.findOne(userId);

    if (data.email && data.email !== existing.email) {
      const emailTaken = await this.db
        .select()
        .from(users)
        .where(eq(users.email, data.email))
        .limit(1)
        .then((r) => r[0]);

      if (emailTaken) {
        throw new ConflictException('Email already exists');
      }
    }

    let passwordHash: string | undefined;

    if (data.password) {
      passwordHash = await bcrypt.hash(data.password, 10);
    }

    const result = await this.db
      .update(users)
      .set({
        email: data.email ?? existing.email,
        firstName: data.firstName ?? existing.firstName,
        lastName: data.lastName ?? existing.lastName,
        ...(passwordHash ? { passwordHash } : {}),
        updatedAt: new Date(),
      })
      .where(eq(users.id, userId))
      .returning();

    const updated = result[0];

    if (!updated) {
      throw new NotFoundException('User not found');
    }

    return this.toSafeUser(updated);
  }
}
