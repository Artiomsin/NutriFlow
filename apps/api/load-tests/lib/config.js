import { check } from 'k6';

const configuredBaseUrl = __ENV.BASE_URL || 'http://127.0.0.1:3000';

export const baseUrl = configuredBaseUrl.replace(/\/$/, '');
export const jsonHeaders = { 'content-type': 'application/json' };

export function requireSafeTarget() {
  const isLocal = /^https?:\/\/(127\.0\.0\.1|localhost)(:\d+)?(\/|$)/.test(
    baseUrl,
  );

  if (!isLocal && __ENV.ALLOW_REMOTE_LOAD_TEST !== 'true') {
    throw new Error(
      'Remote target blocked. Set ALLOW_REMOTE_LOAD_TEST=true only for a dedicated staging environment.',
    );
  }
}

export function authorizedParams(accessToken, name) {
  return {
    headers: { authorization: `Bearer ${accessToken}` },
    tags: { name },
  };
}

export function expectStatus(response, expectedStatus, name) {
  check(response, {
    [`${name} returns ${expectedStatus}`]: (r) => r.status === expectedStatus,
  });
}

export function peakVus(defaultValue) {
  const value = Number(__ENV.LOAD_PEAK_VUS || defaultValue);
  if (!Number.isInteger(value) || value < 1) {
    throw new Error('LOAD_PEAK_VUS must be a positive integer.');
  }
  return value;
}

export function loadTestUserCount(defaultValue) {
  const value = Number(__ENV.LOAD_TEST_USER_COUNT || defaultValue);
  if (!Number.isInteger(value) || value < 1) {
    throw new Error('LOAD_TEST_USER_COUNT must be a positive integer.');
  }
  return value;
}

export function requireProvisioningPermission() {
  if (__ENV.ALLOW_LOAD_TEST_PROVISIONING !== 'true') {
    throw new Error(
      'User provisioning is blocked. Set ALLOW_LOAD_TEST_PROVISIONING=true for an isolated local or staging environment.',
    );
  }
}

export function loadTestRunId() {
  const value = __ENV.LOAD_TEST_RUN_ID;
  if (!value || !/^[a-z0-9-]{3,40}$/i.test(value)) {
    throw new Error(
      'LOAD_TEST_RUN_ID is required and must contain only letters, numbers, and hyphens.',
    );
  }
  return value.toLowerCase();
}

export function loadTestPassword() {
  const value = __ENV.LOAD_TEST_PASSWORD;
  if (!value || value.length < 12) {
    throw new Error(
      'LOAD_TEST_PASSWORD is required and must be at least 12 characters.',
    );
  }
  return value;
}
