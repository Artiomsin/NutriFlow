import { describe, expect, it, mock } from 'bun:test';
import {
  BadGatewayException,
  GatewayTimeoutException,
  ServiceUnavailableException,
} from '@nestjs/common';

import { FoodAnalysisService } from './food-analysis.service';
import type { AnalysisQuotaService } from './analysis-quota.service';
import type { FoodMatcherService } from './food-matcher.service';
import type { VisionImage, VisionProvider } from './vision/vision.types';
import type { FoodAnalysisResult } from './food.schema';

type Analyze = (
  image: VisionImage,
  prompt: string,
  signal: AbortSignal,
) => Promise<string>;

const rawText = (payload: unknown) => JSON.stringify(payload);

const makeProvider = (analyze: Analyze, name = 'test'): VisionProvider => ({
  name,
  analyze: mock(analyze),
});

const okProvider = () => makeProvider(async () => '[]');

const calls = (provider: VisionProvider) =>
  (provider.analyze as ReturnType<typeof mock>).mock.calls;

const file = {
  buffer: Buffer.from('not-a-real-image'),
  mimetype: 'image/png',
  originalname: 'meal.png',
  size: 17,
};

const USER_ID = 'user-1';

// The service reads the shared category list before prompting and validating.
// Tests only need the query to resolve, so a tiny fake covers it.
const systemCategories = (names: string[] = []) => ({
  select: () => ({
    from: () => ({
      where: () => ({
        orderBy: async () => names.map((name) => ({ name })),
      }),
    }),
  }),
});

function setup(
  matcherImpl?: (items: unknown[], userId?: string) => unknown,
  providers?: VisionProvider[],
  categories: string[] = [],
) {
  const matchItems = mock((items: unknown[], userId?: string) =>
    Promise.resolve(matcherImpl ? matcherImpl(items, userId) : items),
  );
  const analysisQuota = {
    tryReserve: mock(async () => ({
      id: 'b1cfa54c-0b86-4115-b81e-5a55b6d6c0d9',
      reservedAt: new Date('2026-10-22T10:00:00.000Z'),
    })),
    consume: mock(async () => {}),
    release: mock(async () => {}),
  };
  const service = new FoodAnalysisService(
    { matchItems } as unknown as FoodMatcherService,
    analysisQuota as unknown as AnalysisQuotaService,
    systemCategories(categories) as never,
  );

  const list = providers ?? [okProvider()];
  (service as unknown as { providers: VisionProvider[] }).providers = list;

  return { service, matchItems, providers: list, analysisQuota };
}

describe('FoodAnalysisService.analyzePhoto', () => {
  it('throws 503 when no provider is configured', async () => {
    const { service } = setup(undefined, []);

    expect(service.analyzePhoto(USER_ID, file)).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });

  it('maps a 503 to ServiceUnavailableException', async () => {
    const provider = makeProvider(async () => {
      throw { status: 503 };
    });
    const { service, analysisQuota } = setup(undefined, [provider]);

    await expect(service.analyzePhoto(USER_ID, file)).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
    expect(analysisQuota.tryReserve).toHaveBeenCalledWith(USER_ID);
    expect(analysisQuota.release).toHaveBeenCalledWith(
      USER_ID,
      expect.any(Object),
    );
  });

  it('maps a 429 to ServiceUnavailableException', async () => {
    const { service } = setup(undefined, [
      makeProvider(async () => {
        throw { error: { code: 429 } };
      }),
    ]);

    expect(service.analyzePhoto(USER_ID, file)).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });

  it('maps an unknown failure to BadGatewayException', async () => {
    const { service } = setup(undefined, [
      makeProvider(async () => {
        throw new Error('boom');
      }),
    ]);

    expect(service.analyzePhoto(USER_ID, file)).rejects.toBeInstanceOf(
      BadGatewayException,
    );
  });

  it('falls back to the next provider when one is unavailable', async () => {
    const first = makeProvider(async () => {
      throw { status: 503 };
    });
    const second = makeProvider(async () =>
      rawText([{ kind: 'water', amountMl: 300, confidence: 1 }]),
    );
    const { service } = setup(undefined, [first, second]);

    const result = await service.analyzePhoto(USER_ID, file);

    expect(result).toEqual([{ kind: 'water', amountMl: 300, confidence: 1 }]);
    expect(first.analyze).toHaveBeenCalledTimes(1);
    expect(second.analyze).toHaveBeenCalledTimes(1);
  });

  it('aborts a timed-out provider without starting a paid fallback', async () => {
    let receivedSignal: AbortSignal | undefined;
    const first = makeProvider(
      async (_image, _prompt, signal) =>
        new Promise<string>((_resolve, reject) => {
          receivedSignal = signal;
          signal.addEventListener('abort', () => reject(signal.reason));
        }),
    );
    const second = okProvider();
    const { service, analysisQuota } = setup(undefined, [first, second]);
    (service as unknown as { providerTimeoutMs: number }).providerTimeoutMs = 1;

    await expect(service.analyzePhoto(USER_ID, file)).rejects.toBeInstanceOf(
      GatewayTimeoutException,
    );

    expect(receivedSignal?.aborted).toBe(true);
    expect(second.analyze).not.toHaveBeenCalled();
    expect(analysisQuota.consume).toHaveBeenCalledTimes(1);
    expect(analysisQuota.release).not.toHaveBeenCalled();
  });

  it('does not fall back when a provider reports a 504 timeout', async () => {
    const first = makeProvider(async () => {
      throw { status: 504 };
    });
    const second = okProvider();
    const { service, analysisQuota } = setup(undefined, [first, second]);

    await expect(service.analyzePhoto(USER_ID, file)).rejects.toBeInstanceOf(
      GatewayTimeoutException,
    );

    expect(second.analyze).not.toHaveBeenCalled();
    expect(analysisQuota.consume).toHaveBeenCalledTimes(1);
    expect(analysisQuota.release).not.toHaveBeenCalled();
  });

  it('falls back to the next provider when one was removed (404)', async () => {
    const first = makeProvider(async () => {
      throw { status: 404 };
    });
    const second = makeProvider(async () => rawText([]));
    const { service } = setup(undefined, [first, second]);

    const result = await service.analyzePhoto(USER_ID, file);

    expect(result).toEqual([]);
    expect(first.analyze).toHaveBeenCalledTimes(1);
    expect(second.analyze).toHaveBeenCalledTimes(1);
  });

  it('falls back on a 403 (region/key blocked) instead of failing', async () => {
    const first = makeProvider(async () => {
      throw { status: 403 };
    });
    const second = makeProvider(async () => rawText([]));
    const { service } = setup(undefined, [first, second]);

    const result = await service.analyzePhoto(USER_ID, file);

    expect(result).toEqual([]);
    expect(first.analyze).toHaveBeenCalledTimes(1);
    expect(second.analyze).toHaveBeenCalledTimes(1);
  });

  it('falls back on a 401 (invalid key) instead of failing', async () => {
    const first = makeProvider(async () => {
      throw { status: 401 };
    });
    const second = makeProvider(async () => rawText([]));
    const { service } = setup(undefined, [first, second]);

    const result = await service.analyzePhoto(USER_ID, file);

    expect(result).toEqual([]);
    expect(second.analyze).toHaveBeenCalledTimes(1);
  });

  it('maps invalid JSON output to BadGatewayException', async () => {
    const { service } = setup(undefined, [
      makeProvider(async () => 'not json'),
    ]);

    expect(service.analyzePhoto(USER_ID, file)).rejects.toBeInstanceOf(
      BadGatewayException,
    );
  });

  it('serves a repeated image from cache without calling providers', async () => {
    const provider = okProvider();
    const { service, analysisQuota } = setup(undefined, [provider]);

    await service.analyzePhoto(USER_ID, file);
    await service.analyzePhoto(USER_ID, file);

    expect(provider.analyze).toHaveBeenCalledTimes(1);
    expect(analysisQuota.tryReserve).toHaveBeenCalledTimes(1);
    expect(analysisQuota.consume).toHaveBeenCalledTimes(1);
  });

  it('runs concurrent analyses of the same image only once', async () => {
    let release: () => void = () => {};
    const gate = new Promise<void>((resolve) => {
      release = resolve;
    });
    const provider = makeProvider(async () => {
      await gate;
      return rawText([]);
    });
    const { service, analysisQuota } = setup(undefined, [provider]);

    const first = service.analyzePhoto(USER_ID, file);
    const second = service.analyzePhoto(USER_ID, file);
    release();

    const [a, b] = await Promise.all([first, second]);

    expect(provider.analyze).toHaveBeenCalledTimes(1);
    expect(analysisQuota.tryReserve).toHaveBeenCalledTimes(1);
    expect(analysisQuota.consume).toHaveBeenCalledTimes(1);
    expect(a).toEqual([]);
    expect(b).toEqual([]);
  });

  it('re-analyzes once a cached entry outlives its TTL', async () => {
    const provider = okProvider();
    const { service } = setup(undefined, [provider]);
    (service as unknown as { cacheTtlMs: number }).cacheTtlMs = 0;

    await service.analyzePhoto(USER_ID, file);
    await service.analyzePhoto(USER_ID, file);

    expect(provider.analyze).toHaveBeenCalledTimes(2);
  });

  it('returns [] for an empty array and skips the matcher', async () => {
    const { service, matchItems } = setup();

    const result = await service.analyzePhoto(USER_ID, file);

    expect(result).toEqual<FoodAnalysisResult>([]);
    expect(matchItems).not.toHaveBeenCalled();
  });

  it('normalizes a single object response into one item', async () => {
    const { service } = setup(undefined, [
      makeProvider(async () =>
        rawText({ kind: 'water', amountMl: 300, confidence: 1 }),
      ),
    ]);

    const result = await service.analyzePhoto(USER_ID, file);

    expect(result).toEqual([{ kind: 'water', amountMl: 300, confidence: 1 }]);
  });

  it('unwraps a { items: [...] } response', async () => {
    const { service } = setup(undefined, [
      makeProvider(async () =>
        rawText({
          items: [{ kind: 'water', amountMl: 250, confidence: 1 }],
        }),
      ),
    ]);

    const result = await service.analyzePhoto(USER_ID, file);

    expect(result).toEqual([{ kind: 'water', amountMl: 250, confidence: 1 }]);
  });

  it('collapses duplicate water detections of the same container into one', async () => {
    const { service } = setup(undefined, [
      makeProvider(async () =>
        rawText([
          { kind: 'water', amountMl: 500, confidence: 0.8 },
          { kind: 'water', amountMl: 550, confidence: 0.95 },
        ]),
      ),
    ]);

    const result = await service.analyzePhoto(USER_ID, file);

    expect(result).toEqual<FoodAnalysisResult>([
      { kind: 'water', amountMl: 550, confidence: 0.95 },
    ]);
  });

  it('keeps water items with clearly different volumes apart', async () => {
    const { service } = setup(undefined, [
      makeProvider(async () =>
        rawText([
          { kind: 'water', amountMl: 250, confidence: 0.9 },
          { kind: 'water', amountMl: 1_000, confidence: 0.9 },
        ]),
      ),
    ]);

    const result = await service.analyzePhoto(USER_ID, file);

    expect(result).toEqual<FoodAnalysisResult>([
      { kind: 'water', amountMl: 250, confidence: 0.9 },
      { kind: 'water', amountMl: 1_000, confidence: 0.9 },
    ]);
  });

  it('does not collapse water with a food item sharing its volume', async () => {
    const { service } = setup(undefined, [
      makeProvider(async () =>
        rawText([
          { kind: 'water', amountMl: 300, confidence: 0.9 },
          {
            kind: 'food',
            name: 'Soup',
            grams: 300,
            calories: 120,
            protein: 4,
            fat: 3,
            carbs: 18,
            unit: 'g',
            confidence: 0.9,
          },
        ]),
      ),
    ]);

    const result = await service.analyzePhoto(USER_ID, file);

    expect(result).toHaveLength(2);
    expect(result[0]).toEqual({
      kind: 'water',
      amountMl: 300,
      confidence: 0.9,
    });
    expect(result[1]).toMatchObject({ kind: 'food', name: 'Soup' });
  });

  it('parses a JSON array wrapped in a markdown fence', async () => {
    const { service } = setup(undefined, [
      makeProvider(
        async () =>
          '```json\n[{"kind":"water","amountMl":200,"confidence":1}]\n```',
      ),
    ]);

    const result = await service.analyzePhoto(USER_ID, file);

    expect(result).toEqual([{ kind: 'water', amountMl: 200, confidence: 1 }]);
  });

  it('rounds food fields and merges the matcher result', async () => {
    const provider = makeProvider(async () =>
      rawText([
        {
          kind: 'food',
          name: 'Rice',
          grams: 100.4,
          calories: 130.6,
          protein: 2.4,
          fat: 0.3,
          carbs: 28.2,
          unit: 'ml',
          confidence: 0.91,
        },
      ]),
    );
    const { service, matchItems } = setup(
      () => [{ kind: 'food', name: 'Catalog Rice', source: 'catalog' }],
      [provider],
    );

    const result = await service.analyzePhoto(USER_ID, file);

    expect(result).toHaveLength(1);
    expect(result[0]).toMatchObject({
      kind: 'food',
      name: 'Catalog Rice',
      source: 'catalog',
    });
    expect(matchItems).toHaveBeenCalledTimes(1);
    const passed = matchItems.mock.calls[0]?.[0] as Array<
      Record<string, unknown>
    >;
    expect(passed).toHaveLength(1);
    expect(passed[0]).toMatchObject({
      grams: 100,
      calories: 131,
      protein: 2,
      fat: 0,
      carbs: 28,
      unit: 'ml',
      confidence: 0.91,
    });
  });

  it('drops items that fail schema validation', async () => {
    const { service, matchItems } = setup(undefined, [
      makeProvider(async () =>
        rawText([
          { kind: 'food' },
          { kind: 'water', amountMl: 5, confidence: 1 },
        ]),
      ),
    ]);

    const result = await service.analyzePhoto(USER_ID, file);

    expect(result).toEqual<FoodAnalysisResult>([]);
    expect(matchItems).not.toHaveBeenCalled();
  });

  it('limits the result to 8 items', async () => {
    const item = {
      kind: 'food',
      name: 'x',
      grams: 1,
      calories: 1,
      protein: 1,
      fat: 1,
      carbs: 1,
      confidence: 1,
    };
    const { service, matchItems } = setup(undefined, [
      makeProvider(async () =>
        rawText(Array.from({ length: 10 }, () => ({ ...item }))),
      ),
    ]);

    const result = await service.analyzePhoto(USER_ID, file);

    expect(result).toHaveLength(8);
    expect((matchItems.mock.calls[0]?.[0] as unknown[]).length).toBe(8);
  });

  it('keeps water between foods in the original order', async () => {
    const { service } = setup(
      (items) =>
        items.map((_, i) => ({
          kind: 'food',
          source: 'catalog',
          name: `M${i}`,
        })),
      [
        makeProvider(async () =>
          rawText([
            { kind: 'food', name: 'A', grams: 1, calories: 1, confidence: 1 },
            { kind: 'water', amountMl: 250, confidence: 1 },
            { kind: 'food', name: 'B', grams: 1, calories: 1, confidence: 1 },
          ]),
        ),
      ],
    );

    const result = await service.analyzePhoto(USER_ID, file);

    expect(result).toHaveLength(3);
    expect(result[0]).toMatchObject({
      kind: 'food',
      source: 'catalog',
      name: 'M0',
    });
    expect(result[1]).toEqual({ kind: 'water', amountMl: 250, confidence: 1 });
    expect(result[2]).toMatchObject({
      kind: 'food',
      source: 'catalog',
      name: 'M1',
    });
  });

  it('collapses duplicate water next to food without losing the plate', async () => {
    const { service } = setup(
      (items) =>
        items.map((_, i) => ({
          kind: 'food',
          source: 'catalog',
          name: `M${i}`,
        })),
      [
        makeProvider(async () =>
          rawText([
            {
              kind: 'food',
              name: 'Plate',
              grams: 350,
              calories: 500,
              confidence: 0.9,
            },
            { kind: 'water', amountMl: 500, confidence: 0.8 },
            { kind: 'water', amountMl: 550, confidence: 0.95 },
          ]),
        ),
      ],
    );

    const result = await service.analyzePhoto(USER_ID, file);

    expect(result).toHaveLength(2);
    expect(result[0]).toMatchObject({
      kind: 'food',
      source: 'catalog',
      name: 'M0',
    });
    expect(result[1]).toEqual({
      kind: 'water',
      amountMl: 550,
      confidence: 0.95,
    });
  });

  it('instructs the model to report the number of identical containers', async () => {
    const provider = okProvider();
    const { service } = setup(undefined, [provider]);

    await service.analyzePhoto(USER_ID, file);

    const prompt = calls(provider)[0]?.[1] as string;
    expect(prompt).toContain('"containers": number');
    expect(prompt).toContain('volume of ONE');
  });

  it('expands one water object into one item per identical container', async () => {
    const { service } = setup(undefined, [
      makeProvider(async () =>
        rawText([
          { kind: 'water', amountMl: 500, containers: 3, confidence: 0.9 },
        ]),
      ),
    ]);

    const result = await service.analyzePhoto(USER_ID, file);

    expect(result).toEqual<FoodAnalysisResult>([
      { kind: 'water', amountMl: 500, confidence: 0.9 },
      { kind: 'water', amountMl: 500, confidence: 0.9 },
      { kind: 'water', amountMl: 500, confidence: 0.9 },
    ]);
  });

  it('does not dedupe water that reports an explicit container count', async () => {
    const { service } = setup(undefined, [
      makeProvider(async () =>
        rawText([
          { kind: 'water', amountMl: 500, containers: 2, confidence: 0.9 },
          { kind: 'water', amountMl: 500, confidence: 0.9 },
        ]),
      ),
    ]);

    const result = await service.analyzePhoto(USER_ID, file);

    // Two bottles from the explicit count plus one separate detection.
    expect(result).toHaveLength(3);
    expect(result.every((item) => item.kind === 'water')).toBe(true);
  });

  it('passes a non-image mime type through to the provider untouched', async () => {
    const provider = okProvider();
    const { service } = setup(undefined, [provider]);

    await service.analyzePhoto(USER_ID, {
      ...file,
      mimetype: 'application/pdf',
    });

    const image = calls(provider)[0]?.[0] as VisionImage;
    expect(image.mimeType).toBe('application/pdf');
  });

  it('sends a broken image buffer as-is after compression fails', async () => {
    const provider = okProvider();
    const { service } = setup(undefined, [provider]);

    await service.analyzePhoto(USER_ID, file);

    const image = calls(provider)[0]?.[0] as VisionImage;
    expect(image.mimeType).toBe('image/png');
    expect(image.data).toBe(file.buffer.toString('base64'));
  });
});
