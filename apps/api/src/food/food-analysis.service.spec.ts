import { describe, expect, it, mock } from 'bun:test';
import {
  BadGatewayException,
  ServiceUnavailableException,
} from '@nestjs/common';

import { FoodAnalysisService } from './food-analysis.service';
import type { FoodMatcherService } from './food-matcher.service';
import type { VisionImage, VisionProvider } from './vision/vision.types';
import type { FoodAnalysisResult } from './food.schema';

type Analyze = (image: VisionImage, prompt: string) => Promise<string>;

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

function setup(
  matcherImpl?: (items: unknown[]) => unknown,
  providers?: VisionProvider[],
) {
  const matchItems = mock(async (items: unknown[]) =>
    matcherImpl ? matcherImpl(items) : items,
  );
  const service = new FoodAnalysisService({
    matchItems,
  } as unknown as FoodMatcherService);

  const list = providers ?? [okProvider()];
  (service as unknown as { providers: VisionProvider[] }).providers = list;

  return { service, matchItems, providers: list };
}

describe('FoodAnalysisService.analyzePhoto', () => {
  it('throws 503 when no provider is configured', async () => {
    const { service } = setup(undefined, []);

    expect(service.analyzePhoto(file)).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });

  it('maps a 503 to ServiceUnavailableException', async () => {
    const provider = makeProvider(async () => {
      throw { status: 503 };
    });
    const { service } = setup(undefined, [provider]);

    expect(service.analyzePhoto(file)).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });

  it('maps a 429 to ServiceUnavailableException', async () => {
    const { service } = setup(undefined, [
      makeProvider(async () => {
        throw { error: { code: 429 } };
      }),
    ]);

    expect(service.analyzePhoto(file)).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });

  it('maps an unknown failure to BadGatewayException', async () => {
    const { service } = setup(undefined, [
      makeProvider(async () => {
        throw new Error('boom');
      }),
    ]);

    expect(service.analyzePhoto(file)).rejects.toBeInstanceOf(
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

    const result = await service.analyzePhoto(file);

    expect(result).toEqual([{ kind: 'water', amountMl: 300, confidence: 1 }]);
    expect(first.analyze).toHaveBeenCalledTimes(1);
    expect(second.analyze).toHaveBeenCalledTimes(1);
  });

  it('falls back to the next provider when one was removed (404)', async () => {
    const first = makeProvider(async () => {
      throw { status: 404 };
    });
    const second = makeProvider(async () => rawText([]));
    const { service } = setup(undefined, [first, second]);

    const result = await service.analyzePhoto(file);

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

    const result = await service.analyzePhoto(file);

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

    const result = await service.analyzePhoto(file);

    expect(result).toEqual([]);
    expect(second.analyze).toHaveBeenCalledTimes(1);
  });

  it('maps invalid JSON output to BadGatewayException', async () => {
    const { service } = setup(undefined, [
      makeProvider(async () => 'not json'),
    ]);

    expect(service.analyzePhoto(file)).rejects.toBeInstanceOf(
      BadGatewayException,
    );
  });

  it('serves a repeated image from cache without calling providers', async () => {
    const provider = okProvider();
    const { service } = setup(undefined, [provider]);

    await service.analyzePhoto(file);
    await service.analyzePhoto(file);

    expect(provider.analyze).toHaveBeenCalledTimes(1);
  });

  it('re-analyzes once a cached entry outlives its TTL', async () => {
    const provider = okProvider();
    const { service } = setup(undefined, [provider]);
    (service as unknown as { cacheTtlMs: number }).cacheTtlMs = 0;

    await service.analyzePhoto(file);
    await service.analyzePhoto(file);

    expect(provider.analyze).toHaveBeenCalledTimes(2);
  });

  it('returns [] for an empty array and skips the matcher', async () => {
    const { service, matchItems } = setup();

    const result = await service.analyzePhoto(file);

    expect(result).toEqual<FoodAnalysisResult>([]);
    expect(matchItems).not.toHaveBeenCalled();
  });

  it('normalizes a single object response into one item', async () => {
    const { service } = setup(undefined, [
      makeProvider(async () =>
        rawText({ kind: 'water', amountMl: 300, confidence: 1 }),
      ),
    ]);

    const result = await service.analyzePhoto(file);

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

    const result = await service.analyzePhoto(file);

    expect(result).toEqual([{ kind: 'water', amountMl: 250, confidence: 1 }]);
  });

  it('parses a JSON array wrapped in a markdown fence', async () => {
    const { service } = setup(undefined, [
      makeProvider(
        async () =>
          '```json\n[{"kind":"water","amountMl":200,"confidence":1}]\n```',
      ),
    ]);

    const result = await service.analyzePhoto(file);

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

    const result = await service.analyzePhoto(file);

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

    const result = await service.analyzePhoto(file);

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

    const result = await service.analyzePhoto(file);

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

    const result = await service.analyzePhoto(file);

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

  it('passes a non-image mime type through to the provider untouched', async () => {
    const provider = okProvider();
    const { service } = setup(undefined, [provider]);

    await service.analyzePhoto({ ...file, mimetype: 'application/pdf' });

    const image = calls(provider)[0]?.[0] as VisionImage;
    expect(image.mimeType).toBe('application/pdf');
  });

  it('sends a broken image buffer as-is after compression fails', async () => {
    const provider = okProvider();
    const { service } = setup(undefined, [provider]);

    await service.analyzePhoto(file);

    const image = calls(provider)[0]?.[0] as VisionImage;
    expect(image.mimeType).toBe('image/png');
    expect(image.data).toBe(file.buffer.toString('base64'));
  });
});
