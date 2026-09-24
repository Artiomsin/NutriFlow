import { eq } from 'drizzle-orm';
import { db } from '../../db/db';
import { userProfiles } from '../../db/schema/userProfiles';

export async function currentUserDate(userId: string): Promise<string> {
  const [profile] = await db
    .select({ timeZone: userProfiles.timeZone })
    .from(userProfiles)
    .where(eq(userProfiles.userId, userId))
    .limit(1);

  return formatDateInTimeZone(new Date(), profile?.timeZone ?? 'UTC');
}

export function formatDateInTimeZone(date: Date, timeZone: string): string {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date);
  const value = (type: Intl.DateTimeFormatPartTypes) =>
    parts.find((part) => part.type === type)?.value;
  return `${value('year')}-${value('month')}-${value('day')}`;
}
