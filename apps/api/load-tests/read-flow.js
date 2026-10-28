import http from 'k6/http';
import { sleep } from 'k6';

import {
  authorizedParams,
  baseUrl,
  expectStatus,
  loadTestUserCount,
  peakVus,
  requireProvisioningPermission,
  requireSafeTarget,
} from './lib/config.js';
import { deleteUsers, provisionUsers, userForVu } from './lib/users.js';

const peak = peakVus(25);
const warmup = Math.min(10, peak);
const userCount = loadTestUserCount(peak);
if (userCount < peak) {
  throw new Error('LOAD_TEST_USER_COUNT must be at least LOAD_PEAK_VUS.');
}

export const options = {
  stages: [
    { duration: '30s', target: warmup },
    { duration: '2m', target: peak },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<1200', 'p(99)<2500'],
  },
};

export function setup() {
  requireSafeTarget();
  requireProvisioningPermission();
  return provisionUsers(userCount);
}

export default function (data) {
  const { accessToken } = userForVu(data);
  const endpoints = [
    ['/api/daily-summary/dashboard', 'GET /api/daily-summary/dashboard'],
    ['/api/activity/today', 'GET /api/activity/today'],
    ['/api/water-tracking/today', 'GET /api/water-tracking/today'],
    ['/api/goals', 'GET /api/goals'],
    ['/api/analytics/week', 'GET /api/analytics/week'],
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
