import { Injectable, Logger } from '@nestjs/common';
import { GoogleGenAI } from '@google/genai';
import sharp from 'sharp';
import { env } from '../config/env';
import {
  foodAnalysisItemSchema,
  type FoodAnalysisItem,
  type FoodAnalysisResult,
} from './food.schema';
import { FoodMatcherService } from './food-matcher.service';

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
      this.logger.warn('GEMINI_API_KEY не задан — возвращаю пустой результат');
      return [];
    }

    try {
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
            'Пункт ответа gemini не прошёл Zod: ' +
              JSON.stringify(result.error.flatten()),
          );
        }
      }

      if (!parsed.length) {
        return [];
      }

      return this.matcher.matchItems(parsed);
    } catch (e) {
      this.logger.error('gemini analyze failed', e as Error);
      return [];
    }
  }

  private async analyzeWithGemini(
    buffer: Buffer,
    mimeType: string,
  ): Promise<unknown> {
    const TIMEOUT_MS = 30_000;

    const response = await Promise.race([
      this.gemini!.models.generateContent({
        model: 'gemini-3.6-flash',
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
      'Gemini raw response: ' + (response.text ?? 'null').slice(0, 1000),
    );

    return JSON.parse(response.text ?? '[]');
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
      'Analyze the food in this photo. There may be one or more dishes.',
      'Split the plate into separate dishes. For each, estimate the portion size in grams.',
      'Return ONLY valid JSON (no markdown): an ARRAY of objects, each:',
      '{ "name": string, "category": string, "grams": number, "calories": number, "protein": number,',
      '  "fat": number, "carbs": number, "unit": "g" | "ml", "confidence": number 0-1 }',
      '"category" is a short food category in English like "Grains", "Meat", "Vegetables", "Dairy", "Breakfast", "Snacks".',
      'If there is only one dish, return an array with a single object.',
      'Nutrients are for the ESTIMATED PORTION, not per 100g.',
      'If unsure, still give your best estimate. Do not omit fields.',
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
    const rounded: Record<string, unknown> = {
      ...raw,
      unit: raw.unit === 'ml' ? 'ml' : 'g',
    };
    for (const k of ['grams', 'calories', 'protein', 'fat', 'carbs']) {
      const v = Number(raw[k]);
      rounded[k] = Number.isFinite(v) ? Math.round(v) : null;
    }
    const conf = Number(raw.confidence);
    rounded.confidence = Number.isFinite(conf) ? conf : null;
    return rounded;
  }
}
