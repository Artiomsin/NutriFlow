import {
  Inject,
  Injectable,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';

import { eq, sql } from 'drizzle-orm';

import type { Db } from '../db/db';
import { DB } from '../db/db.module';
import { users } from '../db/schema/users';
import { userUploads } from '../db/schema/userUploads';
import { storageCleanupTasks } from '../db/schema/storageCleanupTasks';
import { UploadService } from '../upload/upload.service';

import type { UpdateUserDto } from './users.schema';

@Injectable()
export class UsersService {
  constructor(
    @Inject(DB) private readonly db: Db,
    private readonly uploadService: UploadService,
  ) {}

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

    const result = await this.db
      .update(users)
      .set({
        email: data.email ?? existing.email,
        firstName: data.firstName ?? existing.firstName,
        lastName: data.lastName ?? existing.lastName,
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

  /** Permanently deletes the caller and all of their personal data. */
  async deleteMe(userId: string): Promise<void> {
    await this.db.transaction(async (tx) => {
      // This is the same per-user lock used by writes that can race with
      // deletion, including upload registration.
      await tx.execute(sql`SELECT pg_advisory_xact_lock(hashtext(${userId}))`);

      const [existing] = await tx
        .select({ id: users.id })
        .from(users)
        .where(eq(users.id, userId))
        .limit(1);
      if (!existing) throw new NotFoundException('User not found');

      const uploads = await tx
        .select({ objectKey: userUploads.objectKey })
        .from(userUploads)
        .where(eq(userUploads.userId, userId));

      if (uploads.length > 0) {
        await tx
          .insert(storageCleanupTasks)
          .values(uploads)
          .onConflictDoNothing();
      }

      // Cascades remove sessions, profile, diary, goals, health data and
      // personal products. Schema FKs preserve catalog products and snapshots.
      await tx.delete(users).where(eq(users.id, userId));
    });

    // Never turn a successfully committed account deletion into an HTTP error
    // because object storage is temporarily unavailable. The retry task is
    // already durable in PostgreSQL.
    void this.uploadService.processPendingCleanup();
  }
}
