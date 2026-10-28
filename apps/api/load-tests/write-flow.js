import http from 'k6/http';
import { sleep } from 'k6';

import {
  authorizedParams,
  baseUrl,
  expectStatus,
  jsonHeaders,
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
    { duration: '20s', target: 1 },
    { duration: '1m', target: peak },
    { duration: '20s', target: 0 },
  ],
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<1500', 'p(99)<3000'],
  },
};

export function setup() {
  requireSafeTarget();
  requireProvisioningPermission();
  return provisionUsers(userCount);
}

export default function (data) {
  const { accessToken } = userForVu(data);
  const params = {
    ...authorizedParams(accessToken, 'authenticated write'),
    headers: {
      ...jsonHeaders,
      authorization: `Bearer ${accessToken}`,
    },
  };
  const water = http.post(
    `${baseUrl}/api/water-tracking`,
    JSON.stringify({ amountMl: 250 }),
    {
      ...params,
      tags: { name: 'POST /api/water-tracking' },
    },
  );
  expectStatus(water, 201, 'POST /api/water-tracking');

  const food = http.post(
    `${baseUrl}/api/food-entry`,
    JSON.stringify({
      name: `Load test meal ${__VU}`,
      grams: 120,
      calories: 180,
      protein: 8,
      fat: 4,
      carbs: 28,
    }),
    {
      ...params,
      tags: { name: 'POST /api/food-entry' },
    },
  );
  expectStatus(food, 201, 'POST /api/food-entry');

  const foodId = food.status === 201 && food.body ? food.json('id') : null;
  if (foodId) {
    const updateFood = http.patch(
      `${baseUrl}/api/food-entry/${foodId}`,
      JSON.stringify({ calories: 190 }),
      {
        ...params,
        tags: { name: 'PATCH /api/food-entry/:id' },
      },
    );
    expectStatus(updateFood, 200, 'PATCH /api/food-entry/:id');
  }

  const dashboard = http.get(`${baseUrl}/api/daily-summary/dashboard`, {
    ...authorizedParams(accessToken, 'GET /api/daily-summary/dashboard'),
  });
  expectStatus(dashboard, 200, 'GET /api/daily-summary/dashboard');

  const waterId = water.status === 201 && water.body ? water.json('id') : null;
  if (waterId) {
    const removeWater = http.del(
      `${baseUrl}/api/water-tracking/${waterId}`,
      null,
      authorizedParams(accessToken, 'DELETE /api/water-tracking/:id'),
    );
    expectStatus(removeWater, 200, 'DELETE /api/water-tracking/:id');
  }

  if (foodId) {
    const removeFood = http.del(
      `${baseUrl}/api/food-entry/${foodId}`,
      null,
      authorizedParams(accessToken, 'DELETE /api/food-entry/:id'),
    );
    expectStatus(removeFood, 200, 'DELETE /api/food-entry/:id');
  }

  sleep(1);
}

export function teardown(data) {
  deleteUsers(data.users);
}
