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

    const hash = await bcrypt.hash(data.password, 10);

    const result = await db
      .insert(users)
      .values({
        email: data.email,
        passwordHash: hash,
        firstName: data.firstName,
        lastName: data.lastName,
      })
      .returning();

    return result[0];
  }

  async findAll() {
    return db.select().from(users);
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

  async update(id: string, data: UpdateUserDto) {
    const user = await db
      .update(users)
      .set({
        ...data,
        updatedAt: new Date(),
      })
      .where(eq(users.id, id))
      .returning()
      .then(r => r[0]);

    if (!user) {
      throw new NotFoundException('User not found');
    }

    return user;
  }

  async delete(id: string) {
    const user = await db
      .delete(users)
      .where(eq(users.id, id))
      .returning()
      .then(r => r[0]);

    if (!user) {
      throw new NotFoundException('User not found');
    }

    return { message: 'User deleted successfully' };
  }
}