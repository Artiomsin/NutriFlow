import type { VisionImage, VisionProvider } from './vision.types';

export type OpenAiVisionOptions = {
  name: string;
  baseUrl: string;
  apiKey: string;
  model: string;
  extraHeaders?: Record<string, string>;
};

type ChatCompletionResponse = {
  choices?: Array<{ message?: { content?: string } }>;
};

/**
 * Any provider that exposes the OpenAI chat-completions shape (Groq, Zhipu,
 * OVH, ...). The image is sent inline as a data URL and the raw text answer is
 * returned untouched; JSON parsing and validation stay in the caller.
 */
export class OpenAiVisionProvider implements VisionProvider {
  readonly name: string;

  constructor(private readonly options: OpenAiVisionOptions) {
    this.name = `${options.name}:${options.model}`;
  }

  async analyze(
    image: VisionImage,
    prompt: string,
    signal: AbortSignal,
  ): Promise<string> {
    const response = await fetch(
      `${this.options.baseUrl.replace(/\/$/, '')}/chat/completions`,
      {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          authorization: `Bearer ${this.options.apiKey}`,
          ...this.options.extraHeaders,
        },
        body: JSON.stringify({
          model: this.options.model,
          temperature: 0,
          messages: [
            {
              role: 'user',
              content: [
                { type: 'text', text: prompt },
                {
                  type: 'image_url',
                  image_url: {
                    url: `data:${image.mimeType};base64,${image.data}`,
                  },
                },
              ],
            },
          ],
        }),
        signal,
      },
    );

    if (!response.ok) {
      const body = await response.text();
      const error = new Error(
        `${this.name} request failed: ${response.status}`,
      ) as Error & { status?: number; body?: string };
      error.status = response.status;
      error.body = body.slice(0, 1000);
      throw error;
    }

    const json = (await response.json()) as ChatCompletionResponse;
    return json.choices?.[0]?.message?.content ?? '';
  }
}
