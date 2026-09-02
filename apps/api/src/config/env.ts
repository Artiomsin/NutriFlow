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

  GOOGLE_CLIENT_ID: getEnv('GOOGLE_CLIENT_ID'),

  USDA_API_KEY: getEnv('USDA_API_KEY'),

  GEMINI_API_KEY: process.env.GEMINI_API_KEY ?? '',

  S3_ACCESS_KEY_ID: process.env.S3_ACCESS_KEY_ID ?? '',
  S3_SECRET_ACCESS_KEY: process.env.S3_SECRET_ACCESS_KEY ?? '',
  S3_ENDPOINT: process.env.S3_ENDPOINT ?? '',
  S3_BUCKET: process.env.S3_BUCKET ?? '',
  S3_PUBLIC_URL: process.env.S3_PUBLIC_URL ?? '',
};
