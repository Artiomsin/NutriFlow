import {
  BadRequestException,
  Inject,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import type { OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import {
  DeleteObjectCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { env } from '../config/env';
import { randomUUID } from 'node:crypto';
import sharp from 'sharp';
import { and, eq, isNull, lte, sql } from 'drizzle-orm';
import type { Db } from '../db/db';
import { DB } from '../db/db.module';
import { users } from '../db/schema/users';
import { userUploads } from '../db/schema/userUploads';
import { storageCleanupTasks } from '../db/schema/storageCleanupTasks';

const MAX_INPUT_WIDTH = 6000;
const MAX_INPUT_HEIGHT = 6000;
const MAX_INPUT_PIXELS = 20_000_000;
const OUTPUT_MAX_SIZE = 2048;
const CLEANUP_INTERVAL_MS = 60 * 1000;
const CLEANUP_BATCH_SIZE = 50;

@Injectable()
export class UploadService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(UploadService.name);
  private s3: S3Client | null = null;
  private bucket = '';
  private publicUrl = '';
  private cleanupInterval?: ReturnType<typeof setInterval>;

  constructor(@Inject(DB) private readonly db: Db) {
    if (env.S3_ACCESS_KEY_ID && env.S3_ENDPOINT) {
      this.s3 = new S3Client({
        region: env.S3_REGION,
        endpoint: env.S3_ENDPOINT,
        forcePathStyle: true,
        credentials: {
          accessKeyId: env.S3_ACCESS_KEY_ID,
          secretAccessKey: env.S3_SECRET_ACCESS_KEY,
        },
      });
      this.bucket = env.S3_BUCKET;
      this.publicUrl = env.S3_PUBLIC_URL.replace(/\/$/, '');
    }
  }

  onModuleInit() {
    if (!this.s3) return;
    void this.processPendingCleanup();
    this.cleanupInterval = setInterval(
      () => void this.processPendingCleanup(),
      CLEANUP_INTERVAL_MS,
    );
    this.cleanupInterval.unref();
  }

  onModuleDestroy() {
    if (this.cleanupInterval) clearInterval(this.cleanupInterval);
  }

  async upload(userId: string, buffer: Buffer): Promise<string> {
    const image = sharp(buffer, {
      failOn: 'error',
      limitInputPixels: MAX_INPUT_PIXELS,
    });
    const metadata = await image.metadata().catch(() => null);
    const supportedFormats = new Set(['jpeg', 'png', 'webp', 'heif']);

    if (
      !metadata?.format ||
      !supportedFormats.has(metadata.format) ||
      !metadata.width ||
      !metadata.height
    ) {
      throw new BadRequestException(
        'The uploaded file is not a supported image',
      );
    }

    if (
      metadata.width > MAX_INPUT_WIDTH ||
      metadata.height > MAX_INPUT_HEIGHT
    ) {
      throw new BadRequestException(
        'Image dimensions must not exceed 6000×6000 pixels',
      );
    }

    const normalizedBuffer = await image
      .rotate()
      .resize({
        width: OUTPUT_MAX_SIZE,
        height: OUTPUT_MAX_SIZE,
        fit: 'inside',
        withoutEnlargement: true,
      })
      .webp({ quality: 85, effort: 4 })
      .toBuffer()
      .catch(() => {
        throw new BadRequestException(
          'The uploaded image could not be processed',
        );
      });

    if (this.s3) {
      const key = `uploads/${userId}/${randomUUID()}.webp`;
      await this.s3.send(
        new PutObjectCommand({
          Bucket: this.bucket,
          Key: key,
          Body: normalizedBuffer,
          ContentType: 'image/webp',
        }),
      );

      try {
        await this.db.transaction(async (tx) => {
          // Serializes upload registration with account deletion. If deletion
          // won the race, the file is removed below rather than orphaned.
          await tx.execute(
            sql`SELECT pg_advisory_xact_lock(hashtext(${userId}))`,
          );
          const [user] = await tx
            .select({ id: users.id })
            .from(users)
            .where(eq(users.id, userId))
            .limit(1);
          if (!user) throw new NotFoundException('User not found');

          await tx.insert(userUploads).values({
            userId,
            objectKey: key,
            contentType: 'image/webp',
          });
        });
      } catch (error) {
        await this.deleteObject(key).catch(() => undefined);
        throw error;
      }

      return `${this.publicUrl}/${key}`;
    }

    throw new Error(
      'Upload storage not configured. Set S3_ACCESS_KEY_ID, S3_ENDPOINT, S3_BUCKET, S3_PUBLIC_URL',
    );
  }

  /** Best-effort immediate run; the durable task remains for later retries. */
  async processPendingCleanup(): Promise<void> {
    if (!this.s3) return;

    const now = new Date();
    const tasks = await this.db
      .select()
      .from(storageCleanupTasks)
      .where(
        and(
          isNull(storageCleanupTasks.completedAt),
          lte(storageCleanupTasks.nextAttemptAt, now),
        ),
      )
      .limit(CLEANUP_BATCH_SIZE);

    for (const task of tasks) {
      try {
        await this.deleteObject(task.objectKey);
        await this.db
          .update(storageCleanupTasks)
          .set({ completedAt: new Date(), lastError: null })
          .where(eq(storageCleanupTasks.id, task.id));
      } catch (error) {
        const attempts = task.attempts + 1;
        const retryDelayMs = Math.min(60 * 60 * 1000, attempts * 60 * 1000);
        await this.db
          .update(storageCleanupTasks)
          .set({
            attempts,
            nextAttemptAt: new Date(Date.now() + retryDelayMs),
            lastError:
              error instanceof Error
                ? error.message.slice(0, 1000)
                : 'Storage deletion failed',
          })
          .where(eq(storageCleanupTasks.id, task.id));
        this.logger.warn(`Could not delete storage object ${task.objectKey}`);
      }
    }
  }

  private async deleteObject(key: string): Promise<void> {
    if (!this.s3) return;
    await this.s3.send(
      new DeleteObjectCommand({ Bucket: this.bucket, Key: key }),
    );
  }
}
