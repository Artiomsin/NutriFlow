import 'dotenv/config';

function getEnv(key: string): string {
  const value = process.env[key];
  if (!value) {
    throw new Error(`Missing env: ${key}`);
  }
  return value;
}

export const env = {
  DATABASE_URL: getEnv('DATABASE_URL'),

  JWT_ACCESS_SECRET: getEnv('JWT_ACCESS_SECRET'),
  JWT_REFRESH_SECRET: getEnv('JWT_REFRESH_SECRET'),

  JWT_ACCESS_EXPIRES: getEnv('JWT_ACCESS_EXPIRES'),
  JWT_REFRESH_EXPIRES: getEnv('JWT_REFRESH_EXPIRES'),
};
