import { describe, expect, it, mock } from 'bun:test';
import { GUARDS_METADATA } from '@nestjs/common/constants';

import { JwtAuthGuard } from '../auth/jwt.guard';
import type { AuthPayload } from '../auth/types/auth.types';
import { ProfilesController } from './profiles.controller';
import type { ProfilesService } from './profiles.service';

function setup() {
  const profilesService = {
    create: mock(async () => ({ userId: 'user-1' })),
    findByUserId: mock(async () => ({ userId: 'user-1' })),
    updateByUserId: mock(async () => ({ userId: 'user-1' })),
    updateTimeZone: mock(async () => ({ userId: 'user-1' })),
    deleteByUserId: mock(async () => ({ userId: 'user-1' })),
  };

  return {
    controller: new ProfilesController(
      profilesService as unknown as ProfilesService,
    ),
    profilesService,
  };
}

const user = { userId: 'user-1', sessionId: 's-1' } as AuthPayload;
const profile = {
  weight: 75,
  height: 180,
  age: 30,
  gender: 'male' as const,
  goal: 'maintain' as const,
  activityLevel: 'medium' as const,
};

describe('ProfilesController', () => {
  it('guards each route with JwtAuthGuard', () => {
    const methods = [
      'create',
      'findMe',
      'updateMe',
      'updateTimeZone',
      'deleteMe',
    ] as const;

    for (const method of methods) {
      const guards = Reflect.getMetadata(
        GUARDS_METADATA,
        ProfilesController.prototype[method],
      );
      expect(guards).toContain(JwtAuthGuard);
    }
  });

  it('creates a profile with the current user id merged in', async () => {
    const { controller, profilesService } = setup();
    await controller.create(user, profile);
    expect(profilesService.create).toHaveBeenCalledWith({
      ...profile,
      userId: 'user-1',
    });
  });

  it('delegates reads, updates and deletes with the current user id', async () => {
    const { controller, profilesService } = setup();
    await controller.findMe(user);
    await controller.updateMe(user, { goal: 'lose' });
    await controller.updateTimeZone(user, { timeZone: 'Europe/Paris' });
    await controller.deleteMe(user);

    expect(profilesService.findByUserId).toHaveBeenCalledWith('user-1');
    expect(profilesService.updateByUserId).toHaveBeenCalledWith('user-1', {
      goal: 'lose',
    });
    expect(profilesService.updateTimeZone).toHaveBeenCalledWith(
      'user-1',
      'Europe/Paris',
    );
    expect(profilesService.deleteByUserId).toHaveBeenCalledWith('user-1');
  });
});
