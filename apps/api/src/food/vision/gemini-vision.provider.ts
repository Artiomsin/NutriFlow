import { GoogleGenAI } from '@google/genai';
import type { VisionImage, VisionProvider } from './vision.types';

export class GeminiVisionProvider implements VisionProvider {
  readonly name: string;

  private readonly client: GoogleGenAI;

  constructor(
    private readonly model: string,
    apiKey: string,
  ) {
    this.name = `gemini:${model}`;
    this.client = new GoogleGenAI({ apiKey });
  }

  async analyze(image: VisionImage, prompt: string): Promise<string> {
    const response = await this.client.models.generateContent({
      model: this.model,
      contents: [
        { inlineData: { mimeType: image.mimeType, data: image.data } },
        { text: prompt },
      ],
      config: { responseMimeType: 'application/json' },
    });

    return response.text ?? '';
  }
}
