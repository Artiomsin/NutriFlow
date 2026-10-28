import http from 'k6/http';
import { check, sleep } from 'k6';

import {
  authorizedParams,
  baseUrl,
  expectStatus,
  requireProvisioningPermission,
  requireSafeTarget,
} from './lib/config.js';
import { deleteUsers, provisionUsers, userForVu } from './lib/users.js';

export const options = {
  vus: 1,
  iterations: 1,
  thresholds: {
    http_req_failed: ['rate<0.01'],
  },
};

export function setup() {
  requireSafeTarget();
  requireProvisioningPermission();
  const health = http.get(`${baseUrl}/api/health/ready`, {
    tags: { name: 'GET /api/health/ready' },
  });
  if (!check(health, { 'readiness is healthy': (r) => r.status === 200 })) {
    throw new Error(
      `API readiness check failed with HTTP ${health.status}. Start the API at ${baseUrl}.`,
    );
  }
  return provisionUsers(1);
}

export default function (data) {
  const { accessToken } = userForVu(data);
  const endpoints = [
    ['/api/daily-summary/dashboard', 'GET /api/daily-summary/dashboard'],
    ['/api/profiles/me', 'GET /api/profiles/me'],
    ['/api/goals', 'GET /api/goals'],
    ['/api/foods?limit=20&offset=0', 'GET /api/foods'],
  ];

  for (const [path, name] of endpoints) {
    const response = http.get(
      `${baseUrl}${path}`,
      authorizedParams(accessToken, name),
    );
    expectStatus(response, 200, name);
  }

  sleep(1);
}

export function teardown(data) {
  deleteUsers(data.users);
}
