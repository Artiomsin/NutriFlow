export type VisionImage = {
  data: string;
  mimeType: string;
};

/**
 * A single vision backend (one model on one provider). Providers are tried in
 * order, so a request that a provider rejects (429/503/404) falls through to
 * the next one instead of failing the analysis.
 */
export interface VisionProvider {
  readonly name: string;
  analyze(
    image: VisionImage,
    prompt: string,
    signal: AbortSignal,
  ): Promise<string>;
}
