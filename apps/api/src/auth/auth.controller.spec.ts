import { describe, expect, it, mock } from 'bun:test';
import { AuthController } from './auth.controller';
import type { AuthService } from './auth.service';

function makeService() {
  return {
    register: mock(async () => ({ accessToken: 'a', refreshToken: 'r' })),
    login: mock(async () => ({ accessToken: 'a', refreshToken: 'r' })),
    refresh: mock(async () => ({ accessToken: 'a', refreshToken: 'r' })),
    googleLogin: mock(async () => ({ accessToken: 'a', refreshToken: 'r' })),
    appleLogin: mock(async () => ({ accessToken: 'a', refreshToken: 'r' })),
    logout: mock(async () => ({ message: 'Logged out' })),
    logoutAll: mock(async () => ({ message: 'Logged out from all devices' })),
  };
}

function makeController() {
  const service = makeService();
  const controller = new AuthController(service as unknown as AuthService);
  return { service, controller };
}

describe('AuthController', () => {
  it('register delegates the dto to the service', async () => {
    const { service, controller } = makeController();
    const dto = {
      email: 'a@b.com',
      password: 'secret1',
      firstName: 'A',
      lastName: 'B',
    };

    await controller.register(dto);

    expect(service.register).toHaveBeenCalledWith(dto);
  });

  it('login delegates the dto to the service', async () => {
    const { service, controller } = makeController();
    const dto = { email: 'a@b.com', password: 'secret1' };

    await controller.login(dto);

    expect(service.login).toHaveBeenCalledWith(dto);
  });

  it('refresh forwards only the refreshToken string', async () => {
    const { service, controller } = makeController();

    await controller.refresh({ refreshToken: 'tok' });

    expect(service.refresh).toHaveBeenCalledWith('tok');
  });

  it('googleLogin delegates the dto to the service', async () => {
    const { service, controller } = makeController();
    const dto = { idToken: 'id-token' };

    await controller.googleLogin(dto);

    expect(service.googleLogin).toHaveBeenCalledWith(dto);
  });

  it('appleLogin delegates the dto to the service', async () => {
    const { service, controller } = makeController();
    const dto = { identityToken: 'identity-token' };

    await controller.appleLogin(dto);

    expect(service.appleLogin).toHaveBeenCalledWith(dto);
  });

  it('logout forwards userId + sessionId from the payload', async () => {
    const { service, controller } = makeController();

    await controller.logout({ userId: 'u1', sessionId: 's1' });

    expect(service.logout).toHaveBeenCalledWith('u1', 's1');
  });

  it('logoutAll forwards userId', async () => {
    const { service, controller } = makeController();

    await controller.logoutAll({ userId: 'u1', sessionId: 's1' });

    expect(service.logoutAll).toHaveBeenCalledWith('u1');
  });
});
