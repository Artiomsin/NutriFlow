import 'dotenv/config';
import {
  catalogImageUrl,
  checkEnvironment,
  findLocalImage,
  readCatalog,
  seedDatabase,
  slugify,
  type Dish,
} from './lib/catalog';

type ImagesMode = 'cache' | 'none' | 'url';

const args = new Map<string, string>();
const flags = new Set<string>();
for (const raw of process.argv.slice(2)) {
  if (!raw.startsWith('--')) continue;
  const body = raw.slice(2);
  const eq = body.indexOf('=');
  if (eq === -1) flags.add(body);
  else args.set(body.slice(0, eq), body.slice(eq + 1));
}

const parsedLimit = Number.parseInt(args.get('limit') ?? '0', 10);
const limit = Number.isNaN(parsedLimit) ? 0 : parsedLimit;
const imagesMode = (args.get('images') ?? 'cache') as ImagesMode;
const dryRun = flags.has('dry-run');
const allowProd = flags.has('allow-prod');

if (!['cache', 'none', 'url'].includes(imagesMode)) {
  throw new Error('--images must be one of: cache, none, url');
}

/**
 * cache → URL for every dish whose original exists in scripts/data/images
 * url   → URL for every dish (assume already uploaded to S3)
 * none  → no image URLs (image_url = NULL)
 */
async function resolveImageUrls(dishes: Dish[]): Promise<Map<string, string>> {
  const urls = new Map<string, string>();
  if (imagesMode === 'none') return urls;

  for (const dish of dishes) {
    const slug = slugify(dish.name);
    if (imagesMode === 'url') {
      urls.set(dish.name, catalogImageUrl(slug));
      continue;
    }
    const local = await findLocalImage(slug);
    if (local) urls.set(dish.name, catalogImageUrl(slug));
  }
  return urls;
}

async function main(): Promise<void> {
  const databaseUrl = checkEnvironment(allowProd);
  const catalog = await readCatalog();
  const dishes = limit > 0 ? catalog.foods.slice(0, limit) : catalog.foods;

  const imageUrls = await resolveImageUrls(dishes);

  console.log(
    `Dishes: ${dishes.length}, categories: ${catalog.categories.length}, images: ${imagesMode} (${imageUrls.size} urls), dry-run: ${dryRun}`,
  );

  if (dryRun) {
    const counts = new Map<string, number>();
    for (const dish of dishes)
      counts.set(dish.category, (counts.get(dish.category) ?? 0) + 1);
    for (const [name, count] of counts) console.log(`  ${name}: ${count}`);
    console.log('Dry run: no writes performed.');
    return;
  }

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
