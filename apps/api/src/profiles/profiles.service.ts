import {
  BadRequestException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import type { Db } from '../db/db';
import { DB } from '../db/db.module';
import { userProfiles } from '../db/schema/userProfiles';
import { eq } from 'drizzle-orm';
import { GoalsService } from '../goals/goals.service';
import { weightLogs } from '../db/schema/weightLogs';
import { formatDateInTimeZone } from '../common/time/user-date';

import type { CreateProfileDto, UpdateProfileDto } from './profiles.schema';

@Injectable()
export class ProfilesService {
  constructor(
    private goalsService: GoalsService,
    @Inject(DB) private readonly db: Db,
  ) {}

  async create(data: CreateProfileDto & { userId: string }) {
    const timeZone = data.timeZone ?? 'UTC';
    const initialDate = formatDateInTimeZone(new Date(), timeZone);
    const goalStartedAt = data.goalStartedAt ?? new Date();
    this.validateTargetFields({
      weight: data.weight,
      goal: data.goal,
      targetWeightKg: data.targetWeightKg ?? null,
      targetWeightMinKg: data.targetWeightMinKg ?? null,
      targetWeightMaxKg: data.targetWeightMaxKg ?? null,
      weeklyRateKg: data.weeklyRateKg ?? null,
      targetDate: data.targetDate ?? null,
      goalStartedAt,
    });

    const result = await this.db.transaction(async (tx) => {
      const [profile] = await tx
        .insert(userProfiles)
        .values({
          userId: data.userId,
          weight: data.weight,
          height: data.height,
          age: data.age,
          gender: data.gender,
          goal: data.goal,
          activityLevel: data.activityLevel,
          timeZone,
          targetWeightKg: data.targetWeightKg ?? null,
          targetWeightMinKg: data.targetWeightMinKg ?? null,
          targetWeightMaxKg: data.targetWeightMaxKg ?? null,
          weeklyRateKg: data.weeklyRateKg ?? null,
          targetDate: data.targetDate ?? null,
          goalStartedAt,
          preferredUnits: data.preferredUnits ?? {
            weight: 'metric',
            volume: 'metric',
            energy: 'kcal',
          },
        })
        .onConflictDoNothing({ target: userProfiles.userId })
        .returning();

      // POST is idempotent: an existing profile must not create a new initial log
      // or silently replace its calculated goals.
      if (!profile) {
        const [existing] = await tx
          .select()
          .from(userProfiles)
          .where(eq(userProfiles.userId, data.userId))
          .limit(1);
        if (!existing) throw new Error('Profile creation failed');
        return { profile: existing, created: false };
      }

      await tx.insert(weightLogs).values({
        userId: data.userId,
        weightKg: String(data.weight),
        entryDate: initialDate,
        source: 'initial',
      });

      await this.goalsService.calculate(data.userId, tx, {
        reason: 'initial_calculation',
        trigger: 'initial',
      });
      return { profile, created: true };
    });

    return result.profile;
  }

  async findByUserId(userId: string) {
    const profile = await this.findByUserIdSafe(userId);

    if (!profile) {
      throw new NotFoundException('Profile not found');
    }

    return profile;
  }

  async updateByUserId(userId: string, data: UpdateProfileDto) {
    const profile = await this.db.transaction(async (tx) => {
      const [existing] = await tx
        .select()
        .from(userProfiles)
        .where(eq(userProfiles.userId, userId))
        .limit(1);

      if (!existing) throw new NotFoundException('Profile not found');

      const merged = {
        weight: existing.weight,
        height: data.height ?? existing.height,
        age: data.age ?? existing.age,
        gender: data.gender ?? existing.gender,
        goal: (data.goal ?? existing.goal) as
          | 'lose'
          | 'gain'
          | 'maintain'
          | null,
        activityLevel: data.activityLevel ?? existing.activityLevel,
        timeZone: data.timeZone ?? existing.timeZone,
        targetWeightKg:
          data.targetWeightKg === undefined
            ? existing.targetWeightKg
            : data.targetWeightKg,
        targetWeightMinKg:
          data.targetWeightMinKg === undefined
            ? ((existing as any).targetWeightMinKg ?? null)
            : data.targetWeightMinKg,
        targetWeightMaxKg:
          data.targetWeightMaxKg === undefined
            ? ((existing as any).targetWeightMaxKg ?? null)
            : data.targetWeightMaxKg,
        weeklyRateKg:
          data.weeklyRateKg === undefined
            ? existing.weeklyRateKg
            : data.weeklyRateKg,
        targetDate:
          data.targetDate === undefined ? existing.targetDate : data.targetDate,
        goalStartedAt:
          data.goalStartedAt === undefined
            ? existing.goalStartedAt
            : data.goalStartedAt,
      };

      this.validateTargetFields(
        {
          weight: merged.weight,
          goal: merged.goal,
          targetWeightKg: merged.targetWeightKg,
          targetWeightMinKg: merged.targetWeightMinKg,
          targetWeightMaxKg: merged.targetWeightMaxKg,
          weeklyRateKg: merged.weeklyRateKg,
          targetDate: merged.targetDate,
          goalStartedAt: merged.goalStartedAt,
        },
        { validatePastTargetDate: data.targetDate !== undefined },
      );

      const [updated] = await tx
        .update(userProfiles)
        .set({
          // Current weight is managed by explicit weight flows (today's log / onboarding).
          weight: existing.weight,
          height: merged.height,
          age: merged.age,
          gender: merged.gender,
          goal: merged.goal,
          activityLevel: merged.activityLevel,
          timeZone: merged.timeZone,
          targetWeightKg: merged.targetWeightKg,
          targetWeightMinKg: merged.targetWeightMinKg,
          targetWeightMaxKg: merged.targetWeightMaxKg,
          weeklyRateKg: merged.weeklyRateKg,
          targetDate: merged.targetDate,
          goalStartedAt: merged.goalStartedAt,
          preferredUnits:
            data.preferredUnits ?? (existing.preferredUnits as any),
          updatedAt: new Date(),
        })
        .where(eq(userProfiles.userId, userId))
        .returning();

      await this.goalsService.calculate(userId, tx, {
        reason: 'profile_changed',
        trigger: 'profile_changed',
      });
      return updated;
    });

    return profile;
  }

  async deleteByUserId(userId: string) {
    const existing = await this.findByUserIdSafe(userId);

    if (!existing) {
      throw new NotFoundException('Profile not found');
    }

    await this.db.delete(userProfiles).where(eq(userProfiles.userId, userId));

    return { message: 'Profile deleted' };
  }

  async updateTimeZone(userId: string, timeZone: string) {
    const [profile] = await this.db
      .update(userProfiles)
      .set({ timeZone, updatedAt: new Date() })
      .where(eq(userProfiles.userId, userId))
      .returning();

    if (!profile) throw new NotFoundException('Profile not found');
    return profile;
  }

  private validateTargetFields(
    input: {
      weight: number | null;
      goal: 'lose' | 'gain' | 'maintain' | null;
      targetWeightKg: number | null;
      targetWeightMinKg?: number | null;
      targetWeightMaxKg?: number | null;
      weeklyRateKg: number | null;
      targetDate: string | null;
      goalStartedAt: Date | string | null;
    },
    opts?: { validatePastTargetDate?: boolean },
  ) {
    const {
      weight,
      goal,
      targetWeightKg,
      targetWeightMinKg = null,
      targetWeightMaxKg = null,
      weeklyRateKg,
      targetDate,
    } = input;
    const validatePastTargetDate = opts?.validatePastTargetDate ?? true;

    if (weeklyRateKg != null && weeklyRateKg <= 0) {
      throw new BadRequestException('weeklyRateKg must be positive');
    }

    if (validatePastTargetDate && targetDate != null) {
      const today = new Date().toISOString().slice(0, 10);
      if (targetDate < today) {
        throw new BadRequestException('targetDate must not be in the past');
      }
    }

    if (targetDate != null && targetWeightKg == null && goal !== 'maintain') {
      throw new BadRequestException(
        'targetWeightKg is required when targetDate is set',
      );
    }

    if (goal === 'lose') {
      if (
        targetWeightKg != null &&
        weight != null &&
        targetWeightKg >= weight
      ) {
        throw new BadRequestException(
          'targetWeightKg must be less than current weight for lose goal',
        );
      }
    }

    if (goal === 'gain') {
      if (
        targetWeightKg != null &&
        weight != null &&
        targetWeightKg <= weight
      ) {
        throw new BadRequestException(
          'targetWeightKg must be greater than current weight for gain goal',
        );
      }
    }

    const hasMin = targetWeightMinKg != null;
    const hasMax = targetWeightMaxKg != null;
    if (hasMin !== hasMax) {
      throw new BadRequestException(
        'targetWeightMinKg and targetWeightMaxKg must be provided together',
      );
    }
    if (hasMin && hasMax) {
      if (targetWeightMinKg! >= targetWeightMaxKg!) {
        throw new BadRequestException(
          'targetWeightMaxKg must be greater than targetWeightMinKg',
        );
      }
      const width = targetWeightMaxKg! - targetWeightMinKg!;
      if (width < 0.5 || width > 10) {
        throw new BadRequestException(
          'Maintain range width should be between 0.5 and 10 kg',
        );
      }
    }

    if (goal === 'maintain') {
      if (hasMin && hasMax) {
        if (weight != null) {
          if (
            targetWeightMaxKg! < weight - 15 ||
            targetWeightMinKg! > weight + 15
          ) {
            throw new BadRequestException(
              'Maintain range should be reasonably close to current weight',
            );
          }
        }
        if (targetWeightKg != null) {
          if (
            targetWeightKg < targetWeightMinKg! ||
            targetWeightKg > targetWeightMaxKg!
          ) {
            throw new BadRequestException(
              'targetWeightKg must be within maintain range when range is provided',
            );
          }
        }
      } else if (targetWeightKg != null && weight != null) {
        const diff = Math.abs(targetWeightKg - weight);
        if (diff > 10) {
          throw new BadRequestException(
            'For maintain goal, targetWeightKg should be within 10kg of current weight',
          );
        }
      }
      // Maintain with a rate usually means no pace; ignore/allow but it's not meaningful.
    } else if (hasMin || hasMax) {
      throw new BadRequestException(
        'Maintain range is only supported for maintain goal',
      );
    }

    // If targetDate is set, ensure it's after goalStartedAt when both present.
    if (targetDate != null && input.goalStartedAt != null) {
      const started =
        input.goalStartedAt instanceof Date
          ? input.goalStartedAt.toISOString().slice(0, 10)
          : String(input.goalStartedAt).slice(0, 10);
      if (targetDate <= started) {
        throw new BadRequestException('targetDate must be after goalStartedAt');
      }
    }
  }

  private async findByUserIdSafe(userId: string) {
    const [profile] = await this.db
      .select()
      .from(userProfiles)
      .where(eq(userProfiles.userId, userId))
      .limit(1);

    return profile;
  }
}
