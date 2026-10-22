import { describe, expect, it } from 'bun:test';
import { ServiceUnavailableException } from '@nestjs/common';

import { FoodAnalysisService } from '../../src/food/food-analysis.service';
import type { FoodMatcherService } from '../../src/food/food-matcher.service';
import {
  hasAllFixtures,
  readFixture,
  FIXTURE_NAMES,
  type FixtureName,
} from '../utils/fixtures';

/**
 * Evaluation of the real Gemini pipeline against real photos. Runs together
 * with the integration suite whenever a Gemini key and all fixtures are present
 * (skipped in CI, where no key is configured). It is slow and network bound, so
 * calls are rate limited and retried on transient 503/429.
 */
const shouldRun = Boolean(process.env.GEMINI_API_KEY) && hasAllFixtures();
const run = shouldRun ? describe : describe.skip;

const EVAL_USER_ID = 'eval-user';

const matcher = {
  matchItems: (items: unknown[], userId?: string) => {
    // Mirrors the real signature; the eval passes a fixed user id.
    void userId;
    return Promise.resolve(items);
  },
} as unknown as FoodMatcherService;

// The service reads the shared system category list before prompting. The eval
// only exercises the model output, so an empty list is enough.
const emptyCategoriesDb = {
  select: () => ({
    from: () => ({
      where: () => ({
        orderBy: async () => [],
      }),
    }),
  }),
} as never;

// For these fixtures the model must actually recognize the right kind of food.
const expectedFood: Partial<Record<FixtureName, RegExp>> = {
  'meal-single': /chicken|poultry/i,
  'meal-plate': /chicken|potato|broccoli|pea/i,
};

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

// Free tier allows 5 RPM (~1 request / 12s); space calls to avoid 429.
const MIN_GAP_MS = Number(process.env.EVAL_MIN_GAP_MS ?? 12_000);
// One test may need several attempts when the model returns a transient 503, so
// the budget is generous: rate-limit gap + up to ~6 retries with backoff.
const TEST_TIMEOUT_MS = Number(process.env.EVAL_TEST_TIMEOUT_MS ?? 120_000);
let nextAllowedAt = 0;

async function respectRateLimit() {
  const wait = nextAllowedAt - Date.now();
  if (wait > 0) await sleep(wait);
  nextAllowedAt = Date.now() + MIN_GAP_MS;
}

const geminiReason = (error: unknown): string => {
  const message = error instanceof Error ? error.message : String(error);
  if (/too many analysis requests/i.test(message)) {
    return 'rate limit / daily quota exceeded (429)';
  }
  if (/temporarily overloaded/i.test(message)) {
    return 'model temporarily overloaded (503)';
  }
  if (/timed out/i.test(message)) {
    return 'request timed out';
  }
  return message;
};

const isQuotaError = (error: unknown): boolean =>
  error instanceof ServiceUnavailableException &&
  /too many analysis requests/i.test(error.message);

async function analyzeWithRetry(
  service: FoodAnalysisService,
  file: Parameters<FoodAnalysisService['analyzePhoto']>[1],
  attempts = 6,
) {
  // Throttle once per test, not per retry, so retries do not each pay the gap.
  await respectRateLimit();
  for (let attempt = 1; ; attempt += 1) {
    try {
      return await service.analyzePhoto(EVAL_USER_ID, file);
    } catch (error) {
      const reason = geminiReason(error);
      console.error(`[eval] attempt ${attempt}/${attempts}: ${reason}`);

      // A daily quota cannot recover by waiting inside the test — fail fast.
      if (error instanceof ServiceUnavailableException && isQuotaError(error)) {
        throw new Error(
          `Gemini model unavailable: ${geminiReason(error)}. ` +
            'The model will not respond until the quota resets or billing is enabled.',
          { cause: error },
        );
      }

      const retryable = error instanceof ServiceUnavailableException;
      if (!retryable || attempt >= attempts) throw error;
      const waitMs = 3_000 * attempt;
      console.log(`[eval] retrying in ${waitMs / 1000}s...`);
      await sleep(waitMs);
    }
  }
}

run('FoodAnalysisService evaluation (real Gemini)', () => {
  const service = new FoodAnalysisService(
    matcher,
    {
      tryReserve: async () => ({
        id: 'b1cfa54c-0b86-4115-b81e-5a55b6d6c0d9',
        reservedAt: new Date(),
      }),
      consume: async () => {},
      release: async () => {},
    } as never,
    emptyCategoriesDb,
  );

  it.each([...FIXTURE_NAMES])(
    'analyzes %s',
    async (name) => {
      const result = await analyzeWithRetry(service, readFixture(name));

      console.log(
        `[eval] ${name}:`,
        JSON.stringify(
          result.map((item) => ({
            kind: item.kind,
            name: 'name' in item ? item.name : undefined,
            grams: 'grams' in item ? item.grams : undefined,
            calories: 'calories' in item ? item.calories : undefined,
            amountMl: 'amountMl' in item ? item.amountMl : undefined,
          })),
        ),
      );

      expect(Array.isArray(result)).toBe(true);

      if (name === 'meal-single' || name === 'meal-plate') {
        expect(result.length).toBeGreaterThan(0);
      }

      if (name === 'not-food') {
        expect(result.filter((item) => item.kind === 'food').length).toBe(0);
      }

      if (name === 'drink-water') {
        expect(result.some((item) => item.kind === 'water')).toBe(true);
      }

      const expected = expectedFood[name];
      if (expected) {
        const names = result
          .filter((item) => item.kind === 'food')
          .map((item) => ('name' in item ? (item.name ?? '') : ''));
        expect(names.some((food) => expected.test(food))).toBe(true);
      }
    },
    TEST_TIMEOUT_MS,
  );
});
