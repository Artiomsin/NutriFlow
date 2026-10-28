import http from 'k6/http';
import { check } from 'k6';

import {
  authorizedParams,
  baseUrl,
  requireProvisioningPermission,
  requireSafeTarget,
} from './lib/config.js';
import { deleteUsers, provisionUsers, userForVu } from './lib/users.js';

const fixtures = [
  {
    name: 'meal-blurry.jpg',
    mimeType: 'image/jpeg',
    data: open('../test/fixtures/meal-blurry.jpg', 'b'),
  },
  {
    name: 'meal-plate.jpeg',
    mimeType: 'image/jpeg',
    data: open('../test/fixtures/meal-plate.jpeg', 'b'),
  },
  {
    name: 'not-food.jpeg',
    mimeType: 'image/jpeg',
    data: open('../test/fixtures/not-food.jpeg', 'b'),
  },
  {
    name: 'drink-water.png',
    mimeType: 'image/png',
    data: open('../test/fixtures/drink-water.png', 'b'),
  },
  {
    name: 'meal-single.jpeg',
    mimeType: 'image/jpeg',
    data: open('../test/fixtures/meal-single.jpeg', 'b'),
  },
];

export const options = {
  vus: fixtures.length,
  iterations: fixtures.length,
  thresholds: {
    http_req_failed: ['rate<0.01'],
    'http_req_duration{phase:cold}': ['p(95)<30000'],
    'http_req_duration{phase:warm}': ['p(95)<1500'],
  },
};

export function setup() {
  requireSafeTarget();
  requireProvisioningPermission();
  return provisionUsers(fixtures.length);
}

function analyze(accessToken, fixture, phase) {
  return http.post(
    `${baseUrl}/api/food/analyze`,
    { file: http.file(fixture.data, fixture.name, fixture.mimeType) },
    {
      ...authorizedParams(accessToken, 'POST /api/food/analyze'),
      tags: { name: 'POST /api/food/analyze', phase },
    },
  );
}

export default function (data) {
  const user = userForVu(data);
  const fixture = fixtures[(__VU - 1) % fixtures.length];
  const cold = analyze(user.accessToken, fixture, 'cold');
  const coldSucceeded = check(cold, {
    'cold AI analysis succeeds': (response) => response.status === 201,
  });
  if (!coldSucceeded) return;

  const warm = analyze(user.accessToken, fixture, 'warm');
  check(warm, {
    'cached AI analysis succeeds': (response) => response.status === 201,
    'cached AI analysis matches first result': (response) =>
      response.body === cold.body,
  });
}

export function teardown(data) {
  deleteUsers(data.users);
}
