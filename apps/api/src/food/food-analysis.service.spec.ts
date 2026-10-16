import { beforeEach, describe, expect, it, mock } from 'bun:test';
import {
  BadGatewayException,
  ServiceUnavailableException,
} from '@nestjs/common';
import type { FoodMatcherService } from './food-matcher.service';
import type { FoodAnalysisResult } from './food.schema';

const generateContent = mock(async (...args: unknown[]) => {
  void args;
  return { text: '[]' };
});

mock.module('@google/genai', () => ({
  GoogleGenAI: class {
    models = { generateContent };
  },
}));

mock.module('./food-matcher.service', () => ({
  FoodMatcherService: class {},
}));

mock.module('../config/env', () => ({
  env: { GEMINI_API_KEY: 'test-key' },
}));

const { FoodAnalysisService } = await import('./food-analysis.service');

type MatcherFn = (items: unknown[]) => unknown;

const file = {
  buffer: Buffer.from('not-an-image'),
  mimetype: 'image/png',
  originalname: 'meal.png',
  size: 12,
};

function setup(matcherFn?: MatcherFn) {
  const matchItems = mock(async (items: unknown[]) =>
    matcherFn ? matcherFn(items) : items,
  );
  const service = new FoodAnalysisService({
    matchItems,
  } as unknown as FoodMatcherService);
  return { service, matchItems };
}

const rawText = (payload: unknown) => ({ text: JSON.stringify(payload) });

const geminiRequest = () =>
  generateContent.mock.calls[0]?.[0] as unknown as {
    model: string;
    config: { responseMimeType: string };
    contents: Array<{ inlineData: { mimeType: string; data: string } }>;
  };

beforeEach(() => {
  generateContent.mockReset();
  generateContent.mockImplementation(async () => ({ text: '[]' }));
});

describe('FoodAnalysisService.analyzePhoto', () => {
  it('throws 503 when Gemini is not configured', async () => {
    const { service } = setup();
    (service as unknown as { gemini: unknown }).gemini = null;

    expect(service.analyzePhoto(file)).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });

  it('maps a Gemini 503 to ServiceUnavailableException', async () => {
    generateContent.mockImplementation(async () => {
      throw { status: 503 };
    });
    const { service } = setup();

    expect(service.analyzePhoto(file)).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });

  it('maps a Gemini 429 to ServiceUnavailableException', async () => {
    generateContent.mockImplementation(async () => {
      throw { error: { code: 429 } };
    });
    const { service } = setup();

    expect(service.analyzePhoto(file)).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });

  it('maps an unknown Gemini failure to BadGatewayException', async () => {
    generateContent.mockImplementation(async () => {
      throw new Error('boom');
    });
    const { service } = setup();

    expect(service.analyzePhoto(file)).rejects.toBeInstanceOf(
      BadGatewayException,
    );
  });

  it('maps invalid JSON output to BadGatewayException', async () => {
    generateContent.mockImplementation(async () => ({ text: 'not json' }));
    const { service } = setup();

    expect(service.analyzePhoto(file)).rejects.toBeInstanceOf(
      BadGatewayException,
    );
  });

  it('returns [] for an empty array and skips the matcher', async () => {
    const { service, matchItems } = setup();

    const result = await service.analyzePhoto(file);

    expect(result).toEqual<FoodAnalysisResult>([]);
    expect(matchItems).not.toHaveBeenCalled();
  });

  it('normalizes a single object response into one item', async () => {
    generateContent.mockImplementation(async () =>
      rawText({ kind: 'water', amountMl: 300, confidence: 1 }),
    );
    const { service } = setup();

    const result = await service.analyzePhoto(file);

    expect(result).toEqual([{ kind: 'water', amountMl: 300, confidence: 1 }]);
  });

  it('rounds food fields and merges the matcher result', async () => {
    generateContent.mockImplementation(async () =>
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
    const { service, matchItems } = setup(() => [
      { kind: 'food', name: 'Catalog Rice', source: 'catalog' },
    ]);

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
    generateContent.mockImplementation(async () =>
      rawText([
        { kind: 'food' },
        { kind: 'water', amountMl: 5, confidence: 1 },
      ]),
    );
    const { service, matchItems } = setup();

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
    generateContent.mockImplementation(async () =>
      rawText(Array.from({ length: 10 }, () => ({ ...item }))),
    );
    const { service, matchItems } = setup();

    const result = await service.analyzePhoto(file);

    expect(result).toHaveLength(8);
    expect((matchItems.mock.calls[0]?.[0] as unknown[]).length).toBe(8);
  });

  it('keeps water between foods in the original order', async () => {
    generateContent.mockImplementation(async () =>
      rawText([
        { kind: 'food', name: 'A', grams: 1, calories: 1, confidence: 1 },
        { kind: 'water', amountMl: 250, confidence: 1 },
        { kind: 'food', name: 'B', grams: 1, calories: 1, confidence: 1 },
      ]),
    );
    const { service } = setup((items) =>
      items.map((_, i) => ({ kind: 'food', source: 'catalog', name: `M${i}` })),
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

  it('passes a non-image mime type through to Gemini untouched', async () => {
    const { service } = setup();

    await service.analyzePhoto({ ...file, mimetype: 'application/pdf' });

    const request = geminiRequest();
    expect(request.model).toBe('gemini-3.6-flash');
    expect(request.config.responseMimeType).toBe('application/json');
    expect(request.contents[0]?.inlineData.mimeType).toBe('application/pdf');
  });

  it('sends a broken image buffer as-is after compression fails', async () => {
    const { service } = setup();

    await service.analyzePhoto(file);

    const request = geminiRequest();
    expect(request.contents[0]?.inlineData.mimeType).toBe('image/png');
    expect(request.contents[0]?.inlineData.data).toBe(
      file.buffer.toString('base64'),
    );
  });
});
