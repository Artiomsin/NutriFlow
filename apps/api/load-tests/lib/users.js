import http from 'k6/http';
import { check } from 'k6';

import {
  baseUrl,
  jsonHeaders,
  loadTestPassword,
  loadTestRunId,
} from './config.js';

const emailDomain = 'load-test.invalid';

export function userEmail(runId, index) {
  return `load-${runId}-${String(index).padStart(3, '0')}@${emailDomain}`;
}

export function provisionUsers(count) {
  const runId = loadTestRunId();
  const password = loadTestPassword();
  const users = [];

  for (let index = 1; index <= count; index += 1) {
    const email = userEmail(runId, index);
    const register = http.post(
      `${baseUrl}/api/auth/register`,
      JSON.stringify({
        email,
        password,
        firstName: 'Load',
        lastName: `Test ${index}`,
      }),
      { headers: jsonHeaders, tags: { name: 'POST /api/auth/register' } },
    );
    const accessToken =
      register.status === 201 && register.body
        ? register.json('accessToken')
        : null;
    const registered = check(register, {
      'test user registration succeeds': (r) => r.status === 201,
      'test user receives access token': () => Boolean(accessToken),
    });
    if (!registered) {
      throw new Error(
        `Could not create ${email}; use a new LOAD_TEST_RUN_ID or run load:cleanup first.`,
      );
    }

    const profile = http.post(
      `${baseUrl}/api/profiles`,
      JSON.stringify({
        weight: 70,
        height: 175,
        age: 30,
        gender: 'male',
        goal: 'maintain',
        activityLevel: 'medium',
        timeZone: 'UTC',
      }),
      {
        headers: { ...jsonHeaders, authorization: `Bearer ${accessToken}` },
        tags: { name: 'POST /api/profiles' },
      },
    );
    if (
      !check(profile, {
        'test profile creation succeeds': (r) => r.status === 201,
      })
    ) {
      throw new Error(`Could not create a profile for ${email}.`);
    }

    users.push({ email, accessToken });
  }

  return { runId, users };
}

export function userForVu(data) {
  return data.users[(__VU - 1) % data.users.length];
}

export function deleteUsers(users) {
  for (const user of users) {
    const response = http.del(`${baseUrl}/api/users/me`, null, {
      headers: { authorization: `Bearer ${user.accessToken}` },
      tags: { name: 'DELETE /api/users/me' },
    });
    check(response, {
      'test user deletion succeeds': (r) =>
        r.status === 204 || r.status === 404,
    });
  }
}

export function loginExistingUsers(count) {
  const runId = loadTestRunId();
  const password = loadTestPassword();
  const users = [];

  for (let index = 1; index <= count; index += 1) {
    const email = userEmail(runId, index);
    const login = http.post(
      `${baseUrl}/api/auth/login`,
      JSON.stringify({ email, password }),
      { headers: jsonHeaders, tags: { name: 'POST /api/auth/login' } },
    );
    if (login.status === 401 || login.status === 404) continue;
    const accessToken =
      login.status === 201 && login.body ? login.json('accessToken') : null;
    if (
      !check(login, {
        'existing test user login succeeds': (r) => r.status === 201,
      })
    ) {
      throw new Error(`Could not log in ${email} during cleanup.`);
    }
    users.push({ email, accessToken });
  }

  return users;
}
