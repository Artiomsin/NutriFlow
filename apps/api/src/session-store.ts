import { cacheGetSafe } from './redis';

export function sessionKey(userId: string, sessionId: string): string {
  return `refresh:${userId}:${sessionId}`;
}

// Redis — единственный источник истины. Fail-closed гарантирует, что logout
// немедленно работает на всех экземплярах API и при проблеме Redis не даёт
// использовать отозванные access-токены.
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
