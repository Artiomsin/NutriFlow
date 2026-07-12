import {
  Injectable,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';

import { eq } from 'drizzle-orm';
import * as bcrypt from 'bcrypt';

import { db } from '../db/db';
import { users } from '../db/schema/users';

import type { CreateUserDto, UpdateUserDto } from './users.schema';

@Injectable()
export class UsersService {

  async create(data: CreateUserDto) {
    const existing = await db
      .select()
      .from(users)
      .where(eq(users.email, data.email))
      .limit(1)
      .then(r => r[0]);

    if (existing) {
      throw new ConflictException('Email already exists');
    }

    const passwordHash = await bcrypt.hash(data.password, 10);

    const result = await db
      .insert(users)
      .values({
        email: data.email,
        passwordHash,
        firstName: data.firstName,
        lastName: data.lastName,
      })
      .returning();

    return result[0];
  }

  async findAll(limit = 50, offset = 0) {
    return db.select().from(users).limit(limit).offset(offset);
  }

  async findOne(id: string) {
    const user = await db
      .select()
      .from(users)
      .where(eq(users.id, id))
      .limit(1)
      .then(r => r[0]);

    if (!user) {
      throw new NotFoundException('User not found');
    }

    return user;
  }

  async updateMe(userId: string, data: UpdateUserDto) {
    const existing = await this.findOne(userId);

    if (data.email && data.email !== existing.email) {
      const emailTaken = await db
        .select()
        .from(users)
        .where(eq(users.email, data.email))
        .limit(1)
        .then(r => r[0]);

      if (emailTaken) {
        throw new ConflictException('Email already exists');
      }
    }

    let passwordHash: string | undefined;

    if (data.password) {
      passwordHash = await bcrypt.hash(data.password, 10);
    }

    const result = await db
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

    return updated;
  }
}