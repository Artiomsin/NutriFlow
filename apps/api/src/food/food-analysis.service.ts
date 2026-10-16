import {
  Injectable,
  Logger,
  ServiceUnavailableException,
  BadGatewayException,
  GatewayTimeoutException,
} from '@nestjs/common';
import { GoogleGenAI } from '@google/genai';
import sharp from 'sharp';
import { env } from '../config/env';
import {
  foodAnalysisItemSchema,
  type FoodAnalysisFoodItem,
  type FoodAnalysisItem,
  type FoodAnalysisResult,
} from './food.schema';
import { FoodMatcherService } from './food-matcher.service';

// Tried in order; if one model is unavailable (429/503) or removed (404), the
// next one is used. Keep the list here so the fallback chain lives in one place.
const GEMINI_MODELS = [
  'gemini-3.6-flash',
  'gemini-flash-latest',
  'gemini-flash-lite-latest',
] as const;

@Injectable()
export class FoodAnalysisService {
  private readonly logger = new Logger(FoodAnalysisService.name);

  private readonly gemini: GoogleGenAI | null = env.GEMINI_API_KEY
    ? new GoogleGenAI({ apiKey: env.GEMINI_API_KEY })
    : null;

  constructor(private readonly matcher: FoodMatcherService) {}

  private static readonly MAX_ITEMS = 8;

  async analyzePhoto(file: {
    buffer: Buffer;
    mimetype: string;
    originalname: string;
    size: number;
  }): Promise<FoodAnalysisResult> {
    if (!this.gemini) {
      this.logger.warn('GEMINI_API_KEY is not set');
      throw new ServiceUnavailableException(
        'Food analysis service is not configured',
      );
    }

    const { buffer, mimeType } = await this.compressImage(
      file.buffer,
      file.mimetype,
    );

    const raw = await this.analyzeWithGemini(buffer, mimeType);

    const items = this.normalizeItems(raw).slice(
      0,
      FoodAnalysisService.MAX_ITEMS,
    );

    const parsed: FoodAnalysisItem[] = [];
    for (const item of items) {
      const rounded = this.round(item);
      const result = foodAnalysisItemSchema.safeParse(rounded);
      if (result.success) {
        parsed.push(result.data);
      } else {
        this.logger.warn(
          'Gemini response item failed Zod validation: ' +
            JSON.stringify(result.error.flatten()),
        );
      }
    }

    if (!parsed.length) {
      return [];
    }

    const foodItems = parsed.filter(
      (item): item is FoodAnalysisFoodItem => item.kind === 'food',
    );
    const matchedFoodItems = await this.matcher.matchItems(foodItems);

    // Food matching changes food values only. Reinsert those values into the
    // validated array so water stays in the same visual order as the photo.
    let foodIndex = 0;
    return parsed.map((item) => {
      if (item.kind === 'water') {
        return item;
      }

      const matched = matchedFoodItems[foodIndex];
      foodIndex += 1;
      return matched ?? item;
    });
  }

  private async analyzeWithGemini(
    buffer: Buffer,
    mimeType: string,
  ): Promise<unknown> {
    const TIMEOUT_MS = 120_000;
    let lastStatus: number | null = null;

    for (const model of GEMINI_MODELS) {
      try {
        const response = await Promise.race([
          this.gemini!.models.generateContent({
            model,
            contents: [
              {
                inlineData: {
                  mimeType,
                  data: buffer.toString('base64'),
                },
              },
              { text: this.prompt() },
            ],
            config: { responseMimeType: 'application/json' },
          }),
          new Promise<never>((_, reject) =>
            setTimeout(() => reject(new Error('Gemini timeout')), TIMEOUT_MS),
          ),
        ]);

        this.logger.log(
          `Gemini (${model}) raw response: ` +
            (response.text ?? 'null').slice(0, 1000),
        );

        try {
          return JSON.parse(response.text ?? '[]');
        } catch {
          this.logger.warn(`Gemini (${model}) returned invalid JSON`);
          lastStatus = null;
          continue;
        }
      } catch (e) {
        const anyErr = e as { message?: string };

        if (anyErr?.message === 'Gemini timeout') {
          this.logger.error(
            `Gemini (${model}) timed out after ${TIMEOUT_MS / 1000}s`,
          );
          lastStatus = 504;
          continue;
        }

        const status = this.extractStatus(e);
        lastStatus = status;
        this.logger.error(
          `Gemini (${model}) request failed: ${status} — ${
            anyErr?.message ?? 'unknown error'
          }`,
        );

        if (status === 429 || status === 503 || status === 404) {
          this.logger.warn(`Gemini ${model} unavailable, trying next model`);
          continue;
        }

        throw this.toGeminiException(status);
      }
    }

    throw this.toGeminiException(lastStatus);
  }

  private toGeminiException(status: number | null): Error {
    if (status === 504) {
      return new GatewayTimeoutException(
        'Food analysis service timed out. Please try again later.',
      );
    }
    if (status === 429) {
      return new ServiceUnavailableException(
        'Too many analysis requests. Please wait a moment and try again.',
      );
    }
    if (status === 503) {
      return new ServiceUnavailableException(
        'Food analysis service is temporarily overloaded. Please try again later.',
      );
    }
    return new BadGatewayException(
      'Food analysis service failed. Please try again later.',
    );
  }

  private extractStatus(e: unknown): number | null {
    if (typeof e !== 'object' || e === null) return null;

    const anyErr = e as {
      status?: number | string;
      code?: number | string;
      error?: { code?: number | string; status?: number | string };
    };

    const raw =
      anyErr.error?.code ??
      anyErr.code ??
      anyErr.error?.status ??
      anyErr.status;
    if (raw == null) return null;

    const num = typeof raw === 'number' ? raw : Number(raw);
    return Number.isFinite(num) ? num : null;
  }

  private normalizeItems(raw: unknown): Array<Record<string, unknown>> {
    if (Array.isArray(raw)) {
      return raw;
    }
    if (raw && typeof raw === 'object') {
      return [raw as Record<string, unknown>];
    }
    return [];
  }

  private prompt() {
    return [
      'Analyze visible food and plain drinking water in this photo.',
      'There may be one or more food dishes and containers of water.',
      'Return ONLY valid JSON with no markdown: an ARRAY of objects.',
      'Every object must include a "kind" field.',
      'For food return:',
      '{ "kind": "food", "name": string, "category": string, "grams": number,',
      '  "calories": number, "protein": number, "fat": number, "carbs": number,',
      '  "unit": "g" | "ml", "confidence": number }',
      'For plain drinking water return:',
      '{ "kind": "water", "amountMl": number, "confidence": number }',
      'Use kind "water" ONLY for plain still or sparkling water.',
      'Do NOT classify tea, coffee, juice, milk, alcohol, soup, smoothies,',
      'cocktails, or flavored drinks as water.',
      'Use kind "food" for food and calorie-containing drinks.',
      'Nutrients are for the estimated portion, not per 100g.',
    ].join(' ');
  }

  private async compressImage(
    buffer: Buffer,
    mimetype: string,
  ): Promise<{ buffer: Buffer; mimeType: string }> {
    if (!mimetype.startsWith('image/')) {
      return { buffer, mimeType: mimetype };
    }

    try {
      const compressed = await sharp(buffer)
        .rotate()
        .resize({
          width: 1024,
          height: 1024,
          fit: 'inside',
          withoutEnlargement: true,
        })
        .jpeg({ quality: 70, progressive: true })
        .toBuffer();
      this.logger.log(
        `Image compressed: ${buffer.length} -> ${compressed.length} bytes`,
      );

      if (compressed.length >= buffer.length) {
        this.logger.log('Compressed image is larger — sending original');
        return { buffer, mimeType: mimetype };
      }

      return { buffer: compressed, mimeType: 'image/jpeg' };
    } catch (e) {
      this.logger.warn(
        'Image compression failed, sending original: ' + (e as Error).message,
      );
      return { buffer, mimeType: mimetype };
    }
  }

  private round(raw: Record<string, unknown>): Record<string, unknown> {
    const confidence = Number(raw.confidence);
    const roundedConfidence = Number.isFinite(confidence) ? confidence : null;

    if (raw.kind === 'water') {
      const amountMl = Number(raw.amountMl);

      return {
        kind: 'water',
        amountMl: Number.isFinite(amountMl) ? Math.round(amountMl) : null,
        confidence: roundedConfidence,
      };
    }

    const rounded: Record<string, unknown> = {
      ...raw,
      kind: 'food',
      unit: raw.unit === 'ml' ? 'ml' : 'g',
      confidence: roundedConfidence,
    };
    for (const k of ['grams', 'calories', 'protein', 'fat', 'carbs']) {
      const v = Number(raw[k]);
      rounded[k] = Number.isFinite(v) ? Math.round(v) : null;
    }
    return rounded;
  }
}
