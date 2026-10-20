import {
  Injectable,
  Logger,
  ServiceUnavailableException,
  BadGatewayException,
  GatewayTimeoutException,
} from '@nestjs/common';
import { createHash } from 'node:crypto';
import sharp from 'sharp';
import {
  foodAnalysisItemSchema,
  type FoodAnalysisFoodItem,
  type FoodAnalysisItem,
  type FoodAnalysisResult,
} from './food.schema';
import { FoodMatcherService } from './food-matcher.service';
import { buildVisionProviders } from './vision/providers';
import type { VisionProvider } from './vision/vision.types';
import { env } from '../config/env';

const PROVIDER_TIMEOUT_MS = 30_000;
const TIMEOUT_SENTINEL = 'vision-timeout';
const CACHE_MAX_ENTRIES = 500;
const MAX_ITEMS = 8;
// Water items whose volumes differ by at most 30% describe the same container.
const WATER_DUPLICATE_TOLERANCE = 0.3;

type CacheEntry = { result: FoodAnalysisResult; at: number };

@Injectable()
export class FoodAnalysisService {
  private readonly logger = new Logger(FoodAnalysisService.name);

  private readonly cache = new Map<string, CacheEntry>();

  // Analyses currently in flight, keyed by image hash. Concurrent requests for
  // the same image join the existing promise instead of calling the provider
  // again, so a double-tap or a retry cannot spend the quota twice.
  private readonly inFlight = new Map<string, Promise<FoodAnalysisResult>>();

  private readonly cacheTtlMs = env.ANALYSIS_CACHE_TTL_MS;

  private providers: VisionProvider[];

  constructor(private readonly matcher: FoodMatcherService) {
    this.providers = buildVisionProviders();
  }

  async analyzePhoto(file: {
    buffer: Buffer;
    mimetype: string;
    originalname: string;
    size: number;
  }): Promise<FoodAnalysisResult> {
    if (!this.providers.length) {
      this.logger.warn('No vision provider is configured');
      throw new ServiceUnavailableException(
        'Food analysis service is not configured',
      );
    }

    const { buffer, mimeType } = await this.compressImage(
      file.buffer,
      file.mimetype,
    );

    const cacheKey = this.hashImage(buffer);
    const cached = this.cache.get(cacheKey);
    if (cached && Date.now() - cached.at < this.cacheTtlMs) {
      this.logger.log('Vision cache hit, skipping providers');
      return cached.result;
    }
    if (cached) {
      this.cache.delete(cacheKey);
    }

    const pending = this.inFlight.get(cacheKey);
    if (pending) {
      this.logger.log('Vision analysis already in flight, joining it');
      return pending;
    }

    const analysis = this.runAnalysis(cacheKey, buffer, mimeType);
    this.inFlight.set(cacheKey, analysis);
    try {
      return await analysis;
    } finally {
      this.inFlight.delete(cacheKey);
    }
  }

  private async runAnalysis(
    cacheKey: string,
    buffer: Buffer,
    mimeType: string,
  ): Promise<FoodAnalysisResult> {
    const raw = await this.analyzeWithProviders(buffer, mimeType);

    const items = this.normalizeItems(raw).slice(0, MAX_ITEMS);

    const parsed: FoodAnalysisItem[] = [];
    for (const item of items) {
      const rounded = this.round(item);
      const result = foodAnalysisItemSchema.safeParse(rounded);
      if (result.success) {
        parsed.push(result.data);
      } else {
        this.logger.warn(
          'Vision response item failed Zod validation: ' +
            JSON.stringify(result.error.flatten()),
        );
      }
    }

    // Vision models frequently describe one container of water twice (the
    // bottle plus its reflection, label or a second estimate of the same
    // volume). Collapse those near-duplicate water items so a single bottle
    // is logged as a single item.
    const deduped = this.dedupeWater(parsed);

    if (!deduped.length) {
      this.cacheSet(cacheKey, []);
      return [];
    }

    const foodItems = deduped.filter(
      (item): item is FoodAnalysisFoodItem => item.kind === 'food',
    );
    const matchedFoodItems = await this.matcher.matchItems(foodItems);

    // Food matching changes food values only. Reinsert those values into the
    // validated array so water stays in the same visual order as the photo.
    let foodIndex = 0;
    const result = deduped.map((item) => {
      if (item.kind === 'water') {
        return item;
      }

      const matched = matchedFoodItems[foodIndex];
      foodIndex += 1;
      return matched ?? item;
    });

    this.cacheSet(cacheKey, result);
    return result;
  }

  private async analyzeWithProviders(
    buffer: Buffer,
    mimeType: string,
  ): Promise<unknown> {
    const image = { data: buffer.toString('base64'), mimeType };
    const prompt = this.prompt();
    let lastStatus: number | null = null;

    for (const provider of this.providers) {
      try {
        const text = await this.withTimeout(provider.analyze(image, prompt));

        this.logger.log(
          `Vision (${provider.name}) raw response: ${text.slice(0, 1000)}`,
        );

        try {
          return this.parseJson(text);
        } catch {
          this.logger.warn(`Vision (${provider.name}) returned invalid JSON`);
          lastStatus = null;
          continue;
        }
      } catch (e) {
        const anyErr = e as { message?: string };

        if (anyErr?.message === TIMEOUT_SENTINEL) {
          this.logger.error(
            `Vision (${provider.name}) timed out after ${
              PROVIDER_TIMEOUT_MS / 1000
            }s`,
          );
          lastStatus = 504;
          continue;
        }

        const status = this.extractStatus(e);
        lastStatus = status;
        this.logger.error(
          `Vision (${provider.name}) request failed: ${status} — ${
            anyErr?.message ?? 'unknown error'
          }`,
        );

        if (this.isFallbackStatus(status)) {
          this.logger.warn(
            `Vision ${provider.name} unavailable, trying next provider`,
          );
          continue;
        }

        throw this.toException(status);
      }
    }

    throw this.toException(lastStatus);
  }

  private async withTimeout<T>(promise: Promise<T>): Promise<T> {
    let timer: ReturnType<typeof setTimeout> | undefined;
    try {
      return await Promise.race([
        promise,
        new Promise<never>((_, reject) => {
          timer = setTimeout(
            () => reject(new Error(TIMEOUT_SENTINEL)),
            PROVIDER_TIMEOUT_MS,
          );
        }),
      ]);
    } finally {
      clearTimeout(timer);
    }
  }

  private parseJson(text: string): unknown {
    const trimmed = text.trim();
    const withoutFence = trimmed.startsWith('```')
      ? trimmed
          .replace(/^```[a-zA-Z]*\s*/, '')
          .replace(/```$/, '')
          .trim()
      : trimmed;
    return JSON.parse(withoutFence);
  }

  private hashImage(buffer: Buffer): string {
    return createHash('sha256').update(buffer).digest('hex');
  }

  private cacheSet(key: string, result: FoodAnalysisResult): void {
    if (this.cache.size >= CACHE_MAX_ENTRIES) {
      const oldest = this.cache.keys().next().value;
      if (oldest !== undefined) {
        this.cache.delete(oldest);
      }
    }
    this.cache.set(key, { result, at: Date.now() });
  }

  private isFallbackStatus(status: number | null): boolean {
    if (status === null) return false;
    return (
      status === 401 ||
      status === 403 ||
      status === 404 ||
      status === 429 ||
      status >= 500
    );
  }

  private toException(status: number | null): Error {
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
      const wrapped = (raw as { items?: unknown }).items;
      if (Array.isArray(wrapped)) {
        return wrapped as Array<Record<string, unknown>>;
      }
      return [raw as Record<string, unknown>];
    }
    return [];
  }

  /**
   * Collapses water items that describe the same physical container. The
   * first occurrence keeps its position (visual order); the amount and
   * confidence come from the highest-confidence detection in the group.
   * Clearly different volumes (a glass and a bottle) are kept apart.
   */
  private dedupeWater(items: FoodAnalysisItem[]): FoodAnalysisItem[] {
    const kept: FoodAnalysisItem[] = [];

    for (const item of items) {
      if (item.kind !== 'water') {
        kept.push(item);
        continue;
      }

      const duplicateIndex = kept.findIndex(
        (candidate) =>
          candidate.kind === 'water' &&
          this.isSameWaterVolume(candidate.amountMl, item.amountMl),
      );

      const existing = duplicateIndex === -1 ? undefined : kept[duplicateIndex];
      if (duplicateIndex === -1 || existing?.kind !== 'water') {
        kept.push(item);
        continue;
      }

      const existingConfidence = existing.confidence ?? 0;
      const itemConfidence = item.confidence ?? 0;
      const winner = itemConfidence > existingConfidence ? item : existing;

      kept[duplicateIndex] = {
        kind: 'water',
        amountMl: winner.amountMl,
        confidence: winner.confidence,
      };

      this.logger.log(
        `Collapsed duplicate water item (${item.amountMl} ml), ` +
          `keeping one water item at ${winner.amountMl} ml`,
      );
    }

    return kept;
  }

  private isSameWaterVolume(a: number, b: number): boolean {
    const largest = Math.max(a, b);
    if (largest <= 0) return false;
    return Math.abs(a - b) / largest <= WATER_DUPLICATE_TOLERANCE;
  }

  private prompt() {
    return [
      'Analyze visible food and plain drinking water in this photo.',
      'There may be one or more food dishes, and separate containers of water.',
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
      'Return EXACTLY ONE water object per physical container of water.',
      'Never emit several water objects for the same container: a bottle, its',
      'reflection, its label, and its cap are ONE container. If the photo shows',
      'only one container of water, the array must contain exactly one water object.',
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
