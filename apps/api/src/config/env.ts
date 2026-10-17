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

  APPLE_CLIENT_ID: process.env.APPLE_CLIENT_ID ?? '',
  GOOGLE_CLIENT_ID: getEnv('GOOGLE_CLIENT_ID'),

  USDA_API_KEY: getEnv('USDA_API_KEY'),

  GEMINI_API_KEY: process.env.GEMINI_API_KEY ?? '',
  GROQ_API_KEY: process.env.GROQ_API_KEY ?? '',
  GROQ_MODEL: process.env.GROQ_MODEL ?? 'qwen/qwen3.8-27b',
  ANALYSIS_DAILY_LIMIT: Number(process.env.ANALYSIS_DAILY_LIMIT ?? 6),
  ANALYSIS_CACHE_TTL_MS: Number(process.env.ANALYSIS_CACHE_TTL_MS ?? 3_600_000),

  S3_ACCESS_KEY_ID:
    process.env.AWS_ACCESS_KEY_ID ?? process.env.S3_ACCESS_KEY_ID ?? '',
  S3_SECRET_ACCESS_KEY:
    process.env.AWS_SECRET_ACCESS_KEY ?? process.env.S3_SECRET_ACCESS_KEY ?? '',
  S3_ENDPOINT: process.env.AWS_ENDPOINT_URL_S3 ?? process.env.S3_ENDPOINT ?? '',
  S3_REGION: process.env.AWS_REGION ?? process.env.S3_REGION ?? 'us-east-1',
  S3_BUCKET: process.env.S3_BUCKET ?? 'nutriflow-uploads',
  S3_PUBLIC_URL: process.env.S3_PUBLIC_URL ?? '',
};
