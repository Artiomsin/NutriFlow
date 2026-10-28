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

const peak = peakVus(5);
const userCount = loadTestUserCount(peak);
if (userCount < peak) {
  throw new Error('LOAD_TEST_USER_COUNT must be at least LOAD_PEAK_VUS.');
}

export const options = {
  stages: [
    { duration: '30s', target: peak },
    { duration: '2m', target: peak },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<1500', 'p(99)<2000'],
  },
};

export function setup() {
  requireSafeTarget();
  requireProvisioningPermission();
  return provisionUsers(userCount);
}

export default function (data) {
  const { accessToken } = userForVu(data);
  const response = http.get(
    `${baseUrl}/api/foods/search?q=rice&limit=20`,
    authorizedParams(accessToken, 'GET /api/foods/search (USDA cache)'),
  );
  expectStatus(response, 200, 'GET /api/foods/search');
  sleep(1);
}

export function teardown(data) {
  deleteUsers(data.users);
}
