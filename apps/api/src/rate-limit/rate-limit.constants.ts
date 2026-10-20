export const RATE_LIMIT_SCOPE = 'rate-limit:scope';
export const USER_RATE_LIMIT = 'rate-limit:user';

export type UserRateLimitOptions = {
  scope: string;
  limit: number;
  ttl: number;
};
