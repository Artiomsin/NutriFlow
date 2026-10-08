import { cacheGetSafe } from './redis';

export function sessionKey(userId: string, sessionId: string): string {
  return `refresh:${userId}:${sessionId}`;
}

// Redis is the single source of truth. Fail-closed guarantees that logout
// works immediately across all API instances and that a Redis outage never
// allows revoked access tokens to be used.
export async function sessionAlive(
  userId: string,
  sessionId: string,
): Promise<boolean> {
  const key = sessionKey(userId, sessionId);

  const res = await cacheGetSafe<string>(key);
  return res.status === 'ok' && res.value !== null;
}

export function invalidateLocalSession(_userId: string, _sessionId: string): void {}

export function invalidateAllSessions(_userId: string): void {}
