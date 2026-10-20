import 'dotenv/config';
import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import sharp from 'sharp';
import {
  IMAGES_DIR,
  catalogImageUrl,
  checkEnvironment,
  findLocalImage,
  readCatalog,
  seedDatabase,
  slugify,
  type Dish,
} from './lib/catalog';

const args = new Map<string, string>();
const flags = new Set<string>();
for (const raw of process.argv.slice(2)) {
  if (!raw.startsWith('--')) continue;
  const body = raw.slice(2);
  const eq = body.indexOf('=');
  if (eq === -1) flags.add(body);
  else args.set(body.slice(0, eq), body.slice(eq + 1));
}

const IMAGE_MODES = [
  'auto',
  'local',
  'pexels',
  'pixabay',
  'placeholder',
  'skip',
] as const;
type ImageMode = (typeof IMAGE_MODES)[number];

const imagesMode = (args.get('images') ?? 'auto') as ImageMode;
if (!IMAGE_MODES.includes(imagesMode)) {
  throw new Error(
    `Unknown --images mode "${imagesMode}". Use one of: ${IMAGE_MODES.join(', ')}.`,
  );
}

const parsedLimit = Number.parseInt(args.get('limit') ?? '0', 10);
const limit = Number.isNaN(parsedLimit) ? 0 : parsedLimit;
const parsedConcurrency = Number.parseInt(args.get('concurrency') ?? '6', 10);
const concurrency =
  Number.isNaN(parsedConcurrency) || parsedConcurrency < 1
    ? 6
    : parsedConcurrency;
const dryRun = flags.has('dry-run');
const allowProd = flags.has('allow-prod');
const parsedMaxWait = Number.parseInt(args.get('max-wait') ?? '0', 10);
const maxWaitMs =
  (Number.isNaN(parsedMaxWait) ? 0 : Math.max(parsedMaxWait, 0)) * 60_000;

const pexelsKey = process.env.PEXELS_API_KEY ?? '';
const pixabayKey = process.env.PIXABAY_API_KEY ?? '';
const stats = { local: 0, fetched: 0, missing: 0, placeholder: 0 };
const credits: Record<string, { photographer: string; photoUrl: string }> = {};

const s3 = {
  endpoint: process.env.AWS_ENDPOINT_URL_S3 ?? process.env.S3_ENDPOINT ?? '',
  region: process.env.AWS_REGION ?? process.env.S3_REGION ?? 'us-east-1',
  accessKeyId:
    process.env.AWS_ACCESS_KEY_ID ?? process.env.S3_ACCESS_KEY_ID ?? '',
  secretAccessKey:
    process.env.AWS_SECRET_ACCESS_KEY ?? process.env.S3_SECRET_ACCESS_KEY ?? '',
  bucket: process.env.S3_BUCKET ?? 'nutriflow-uploads',
  publicUrl: (process.env.S3_PUBLIC_URL ?? '').replace(/\/+$/, ''),
};

const s3Ready = Boolean(
  s3.endpoint && s3.accessKeyId && s3.secretAccessKey && s3.publicUrl,
);

let client: S3Client | null = null;

function s3Client(): S3Client {
  if (!client) {
    client = new S3Client({
      region: s3.region,
      endpoint: s3.endpoint,
      forcePathStyle: true,
      credentials: {
        accessKeyId: s3.accessKeyId,
        secretAccessKey: s3.secretAccessKey,
      },
    });
  }
  return client;
}

async function runPool<T>(
  items: T[],
  size: number,
  worker: (item: T, index: number) => Promise<void>,
): Promise<void> {
  const queue = items.map((item, index) => ({ item, index }));
  const runners: Promise<void>[] = [];
  for (let i = 0; i < size; i += 1) {
    runners.push(
      (async () => {
        for (;;) {
          const next = queue.shift();
          if (!next) return;
          await worker(next.item, next.index);
        }
      })(),
    );
  }
  await Promise.all(runners);
}

function escapeXml(value: string): string {
  return value.replace(
    /[<>&'"]/g,
    (ch) =>
      ({
        '<': '&lt;',
        '>': '&gt;',
        '&': '&amp;',
        "'": '&apos;',
        '"': '&quot;',
      })[ch] ?? ch,
  );
}

function placeholderSvg(name: string): Buffer {
  let hue = 0;
  for (const ch of name) hue = (hue + ch.charCodeAt(0)) % 360;
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="800" height="800"><rect width="100%" height="100%" fill="hsl(${hue}, 55%, 45%)"/><text x="400" y="400" font-family="Helvetica, Arial, sans-serif" font-size="44" font-weight="700" fill="#ffffff" text-anchor="middle" dominant-baseline="middle">${escapeXml(name)}</text></svg>`;
  return Buffer.from(svg);
}

async function uploadImage(input: Buffer, slug: string): Promise<string> {
  const webp = await sharp(input, { failOn: 'error' })
    .rotate()
    .resize({
      width: 1200,
      height: 1200,
      fit: 'inside',
      withoutEnlargement: true,
    })
    .webp({ quality: 85 })
    .toBuffer();
  const key = `catalog/${slug}.webp`;
  try {
    await s3Client().send(
      new PutObjectCommand({
        Bucket: s3.bucket,
        Key: key,
        Body: webp,
        ContentType: 'image/webp',
      }),
    );
  } catch (err) {
    throw new Error(`S3 upload failed for ${key}: ${describeError(err)}`, {
      cause: err,
    });
  }
  // Public URL goes through the API media proxy (MEDIA_BASE_URL), not the
  // raw storage host, so the stored path stays stable if storage changes.
  return catalogImageUrl(slug);
}

function describeError(err: unknown): string {
  if (err instanceof Error) {
    const cause = (err as { cause?: unknown }).cause;
    const extra = cause instanceof Error ? ` <- ${cause.message}` : '';
    return `${err.name}: ${err.message}${extra}`;
  }
  try {
    return JSON.stringify(err);
  } catch {
    return String(err);
  }
}

async function resolveImage(dish: Dish, slug: string): Promise<string | null> {
  const buffer = await sourceBuffer(dish, slug);
  if (!buffer) return null;
  return uploadImage(buffer, slug);
}

type PexelsPhoto = {
  photographer?: string;
  url?: string;
  src?: { large?: string; large2x?: string; original?: string };
};

type PexelsResponse = { photos?: PexelsPhoto[] };

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function rateLimitedFetch(
  label: string,
  url: string,
  init?: { headers?: Record<string, string> },
): Promise<Response> {
  const deadline = Date.now() + maxWaitMs;
  for (;;) {
    const res = await fetch(url, init);
    if (res.status !== 429) return res;
    const remaining = deadline - Date.now();
    if (remaining <= 0) {
      throw new Error(
        `${label} rate limit reached. Progress is cached locally - just re-run the command to continue.`,
      );
    }
    const waitMs = Math.min(60_000, remaining);
    console.log(
      `  ${label} 429, waiting ${Math.ceil(waitMs / 1000)}s (~${Math.ceil(remaining / 1000)}s budget left)`,
    );
    await sleep(waitMs);
  }
}

function provider(): 'pexels' | 'pixabay' | null {
  if (imagesMode === 'pexels') return 'pexels';
  if (imagesMode === 'pixabay') return 'pixabay';
  if (imagesMode === 'auto') {
    if (pixabayKey) return 'pixabay';
    if (pexelsKey) return 'pexels';
  }
  return null;
}

async function cacheImage(
  buffer: Buffer,
  slug: string,
  contentType: string,
): Promise<void> {
  const ext = contentType.includes('png')
    ? 'png'
    : contentType.includes('webp')
      ? 'webp'
      : 'jpg';
  try {
    await writeFile(`${IMAGES_DIR}${slug}.${ext}`, buffer);
  } catch {
    console.warn(`  could not cache ${slug}.${ext} locally`);
  }
}

async function fetchPexels(dish: Dish, slug: string): Promise<Buffer | null> {
  if (!pexelsKey) throw new Error('PEXELS_API_KEY is not set');
  const url = `https://api.pexels.com/v1/search?query=${encodeURIComponent(dish.name)}&per_page=1&orientation=square`;
  const res = await rateLimitedFetch('Pexels', url, {
    headers: { Authorization: pexelsKey },
  });
  if (!res.ok) {
    console.warn(`  pexels "${dish.name}" -> HTTP ${res.status}`);
    return null;
  }
  const data = (await res.json()) as PexelsResponse;
  const photo = data.photos?.[0];
  const src = photo?.src?.large2x ?? photo?.src?.large ?? photo?.src?.original;
  if (!src) return null;
  const image = await fetch(src);
  if (!image.ok) return null;
  const buffer = Buffer.from(await image.arrayBuffer());
  await cacheImage(buffer, slug, image.headers.get('content-type') ?? '');
  if (photo?.photographer) {
    credits[slug] = {
      photographer: photo.photographer,
      photoUrl: photo.url ?? src,
    };
  }
  return buffer;
}

type PixabayHit = {
  user?: string;
  pageURL?: string;
  largeImageURL?: string;
  webformatURL?: string;
};

type PixabayResponse = { hits?: PixabayHit[] };

async function fetchPixabay(dish: Dish, slug: string): Promise<Buffer | null> {
  if (!pixabayKey) throw new Error('PIXABAY_API_KEY is not set');
  const url = `https://pixabay.com/api/?key=${pixabayKey}&q=${encodeURIComponent(dish.name)}&image_type=photo&per_page=3&safesearch=true`;
  const res = await rateLimitedFetch('Pixabay', url);
  if (!res.ok) {
    console.warn(`  pixabay "${dish.name}" -> HTTP ${res.status}`);
    return null;
  }
  const data = (await res.json()) as PixabayResponse;
  const hit = data.hits?.[0];
  const src = hit?.largeImageURL ?? hit?.webformatURL;
  if (!src) return null;
  const image = await fetch(src);
  if (!image.ok) return null;
  const buffer = Buffer.from(await image.arrayBuffer());
  await cacheImage(buffer, slug, image.headers.get('content-type') ?? '');
  if (hit?.user) {
    credits[slug] = { photographer: hit.user, photoUrl: hit.pageURL ?? src };
  }
  return buffer;
}

async function fetchRemote(dish: Dish, slug: string): Promise<Buffer | null> {
  const active = provider();
  if (active === 'pixabay') return fetchPixabay(dish, slug);
  if (active === 'pexels') return fetchPexels(dish, slug);
  return null;
}

async function sourceBuffer(dish: Dish, slug: string): Promise<Buffer | null> {
  if (imagesMode !== 'placeholder') {
    const local = await findLocalImage(slug);
    if (local) {
      stats.local += 1;
      return readFile(local);
    }
    if (imagesMode === 'local') {
      stats.missing += 1;
      return null;
    }
    const remote = await fetchRemote(dish, slug);
    if (remote) {
      stats.fetched += 1;
      return remote;
    }
    if (imagesMode !== 'auto') {
      stats.missing += 1;
      return null;
    }
  }
  stats.placeholder += 1;
  return placeholderSvg(dish.name);
}

async function uploadAllImages(dishes: Dish[]): Promise<Map<string, string>> {
  const urls = new Map<string, string>();
  if (imagesMode === 'skip') return urls;
  if (!s3Ready) {
    throw new Error(
      'S3 is not configured (need AWS_ENDPOINT_URL_S3, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, S3_PUBLIC_URL). Use --images=skip to bypass.',
    );
  }
  const active = provider();
  if (active === 'pexels' && !pexelsKey) {
    throw new Error(
      'PEXELS_API_KEY is not set (add it to apps/api/.env, or use --images=pixabay|local|placeholder|skip).',
    );
  }
  if (active === 'pixabay' && !pixabayKey) {
    throw new Error(
      'PIXABAY_API_KEY is not set (add it to apps/api/.env, or use --images=pexels|local|placeholder|skip).',
    );
  }
  let done = 0;
  try {
    await runPool(dishes, concurrency, async (dish) => {
      const url = await resolveImage(dish, slugify(dish.name));
      if (url) urls.set(dish.name, url);
      done += 1;
      if (done % 25 === 0 || done === dishes.length)
        console.log(`  images ${done}/${dishes.length}`);
    });
  } finally {
    await reportImages();
  }
  return urls;
}

async function reportImages(): Promise<void> {
  if (Object.keys(credits).length > 0) {
    await writeFile(
      fileURLToPath(new URL('./data/credits.json', import.meta.url)),
      `${JSON.stringify(credits, null, 2)}\n`,
    );
    console.log(`  credits written for ${Object.keys(credits).length} photos`);
  }
  console.log(
    `  images: local ${stats.local}, remote ${stats.fetched}, placeholder ${stats.placeholder}, missing ${stats.missing}`,
  );
}

async function main(): Promise<void> {
  const databaseUrl = checkEnvironment(allowProd);
  const catalog = await readCatalog();
  const dishes = limit > 0 ? catalog.foods.slice(0, limit) : catalog.foods;

  console.log(
    `Dishes: ${dishes.length}, categories: ${catalog.categories.length}, images: ${imagesMode}, dry-run: ${dryRun}`,
  );

  if (dryRun) {
    const counts = new Map<string, number>();
    for (const dish of dishes)
      counts.set(dish.category, (counts.get(dish.category) ?? 0) + 1);
    for (const [name, count] of counts) console.log(`  ${name}: ${count}`);
    console.log('Dry run: no writes performed.');
    return;
  }

  const imageUrls = await uploadAllImages(dishes);
  const summary = await seedDatabase(
    databaseUrl,
    catalog,
    dishes,
    (dish) => imageUrls.get(dish.name) ?? null,
  );
  console.log(
    `Done. foods: ${summary.foods}, servings: ${summary.servings}, images: ${imageUrls.size}`,
  );
}

main().catch((err: unknown) => {
  if (err instanceof Error) {
    console.error(`${err.name}: ${err.message}`);
    if (err.stack) console.error(err.stack);
  } else {
    console.error('Thrown value:', err);
  }
  process.exitCode = 1;
});
