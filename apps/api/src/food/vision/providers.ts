import { env } from '../../config/env';
import { GeminiVisionProvider } from './gemini-vision.provider';
import { OpenAiVisionProvider } from './openai-vision.provider';
import type { VisionProvider } from './vision.types';

// Tried in order within Gemini when the primary model is unavailable (429/503)
// or removed (404).
const GEMINI_MODELS = [
  'gemini-3.6-flash',
  'gemini-flash-latest',
  'gemini-flash-lite-latest',
] as const;

/**
 * Builds the ordered provider chain from the environment. Free/fast providers
 * go first; unconfigured ones are simply skipped, so adding a key is enough to
 * put it in the chain.
 */
export function buildVisionProviders(): VisionProvider[] {
  const providers: VisionProvider[] = [];

  if (env.GROQ_API_KEY) {
    providers.push(
      new OpenAiVisionProvider({
        name: 'groq',
        baseUrl: 'https://api.groq.com/openai/v1',
        apiKey: env.GROQ_API_KEY,
        model: env.GROQ_MODEL,
      }),
    );
  }

  if (env.GEMINI_API_KEY) {
    for (const model of GEMINI_MODELS) {
      providers.push(new GeminiVisionProvider(model, env.GEMINI_API_KEY));
    }
  }

  return providers;
}
