import { eq } from 'drizzle-orm';
import type { Db } from '../../db/db';
import { userProfiles } from '../../db/schema/userProfiles';

export async function currentUserDate(
  userId: string,
  executor: Pick<Db, 'select'>,
): Promise<string> {
  const [profile] = await executor
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

/** Offset of `timeZone` from UTC at the given instant, in milliseconds. */
function timeZoneOffsetMs(date: Date, timeZone: string): number {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone,
    hourCycle: 'h23',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  }).formatToParts(date);
  const value = (type: Intl.DateTimeFormatPartTypes) =>
    Number(parts.find((part) => part.type === type)?.value);
  const asUtc = Date.UTC(
    value('year'),
    value('month') - 1,
    value('day'),
    value('hour'),
    value('minute'),
    value('second'),
  );
  return asUtc - date.getTime();
}

/** UTC instant corresponding to 00:00 local time on `date` in `timeZone`. */
function zonedMidnightUtc(date: string, timeZone: string): Date {
  const target = new Date(`${date}T00:00:00.000Z`);
  let offset = timeZoneOffsetMs(target, timeZone);
  let result = new Date(target.getTime() - offset);
  // Re-evaluate the offset at the resolved instant so DST boundaries land on
  // the correct local midnight instead of the pre-transition one.
  offset = timeZoneOffsetMs(result, timeZone);
  result = new Date(target.getTime() - offset);
  return result;
}

/**
 * UTC [start, end) range covering the calendar day `date` in `timeZone`.
 * Using the profile time zone keeps a goal change made at 01:00 local time from
 * leaking into the previous UTC day.
 */
export function zonedDayRange(
  date: string,
  timeZone: string,
): { start: Date; end: Date } {
  const next = new Date(`${date}T00:00:00.000Z`);
  next.setUTCDate(next.getUTCDate() + 1);
  const nextDate = next.toISOString().slice(0, 10);
  return {
    start: zonedMidnightUtc(date, timeZone),
    end: zonedMidnightUtc(nextDate, timeZone),
  };
}
