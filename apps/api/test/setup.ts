import 'reflect-metadata';

process.env.NODE_ENV ??= 'test';

const defaults: Record<string, string> = {
  JWT_ACCESS_SECRET: 'test-access',
  JWT_REFRESH_SECRET: 'test-refresh',
  JWT_ACCESS_EXPIRES: '15m',
  JWT_REFRESH_EXPIRES: '30d',
  GOOGLE_CLIENT_ID: 'test-google',
  USDA_API_KEY: 'test-usda',
};
for (const [k, v] of Object.entries(defaults)) process.env[k] ??= v;

if (!process.env.TEST_DATABASE_URL && !process.env.DATABASE_URL) {
  throw new Error(
    'Set TEST_DATABASE_URL (or DATABASE_URL) before running tests',
  );
}
