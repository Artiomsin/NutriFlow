import http from 'k6/http';
import { check } from 'k6';

import {
  baseUrl,
  requireProvisioningPermission,
  requireSafeTarget,
} from './lib/config.js';
import { deleteUsers, provisionUsers, userForVu } from './lib/users.js';

const image = open('../test/fixtures/meal-single.jpeg', 'b');

export const options = {
  vus: 1,
  iterations: 1,
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<5000'],
  },
};

export function setup() {
  requireSafeTarget();
  requireProvisioningPermission();
  return provisionUsers(1);
}

export default function (data) {
  const { accessToken } = userForVu(data);
  const upload = http.post(
    `${baseUrl}/api/food/upload`,
    { file: http.file(image, 'meal-single.jpeg', 'image/jpeg') },
    {
      headers: { authorization: `Bearer ${accessToken}` },
      tags: { name: 'POST /api/food/upload' },
    },
  );
  const uploadId =
    upload.status === 201 && upload.body ? upload.json('uploadId') : null;
  const valid = check(upload, {
    'upload succeeds': (r) => r.status === 201,
    'upload returns an id': () => Boolean(uploadId),
  });
  if (!valid) return;

  const download = http.get(`${baseUrl}/api/uploads/${uploadId}`, {
    headers: { authorization: `Bearer ${accessToken}` },
    tags: { name: 'GET /api/uploads/:id' },
  });
  check(download, { 'owner can retrieve upload': (r) => r.status === 200 });
}

export function teardown(data) {
  deleteUsers(data.users);
}
