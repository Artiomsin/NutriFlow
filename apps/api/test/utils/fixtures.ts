import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const FIXTURE_DIR = join(import.meta.dir, '..', 'fixtures');

export type FixtureName =
  | 'meal-single'
  | 'meal-plate'
  | 'drink-water'
  | 'meal-blurry'
  | 'not-food';

const FILES: Record<FixtureName, { file: string; mimetype: string }> = {
  'meal-single': { file: 'meal-single.jpeg', mimetype: 'image/jpeg' },
  'meal-plate': { file: 'meal-plate.jpeg', mimetype: 'image/jpeg' },
  'drink-water': { file: 'drink-water.png', mimetype: 'image/png' },
  'meal-blurry': { file: 'meal-blurry.jpg', mimetype: 'image/jpeg' },
  'not-food': { file: 'not-food.jpeg', mimetype: 'image/jpeg' },
};

export const FIXTURE_NAMES = Object.keys(FILES) as FixtureName[];

export function fixturePath(name: FixtureName): string {
  return join(FIXTURE_DIR, FILES[name].file);
}

export function readFixture(name: FixtureName): {
  buffer: Buffer;
  mimetype: string;
  originalname: string;
  size: number;
} {
  const { file, mimetype } = FILES[name];
  const buffer = readFileSync(join(FIXTURE_DIR, file));
  return {
    buffer,
    mimetype,
    originalname: file,
    size: buffer.length,
  };
}

export function hasAllFixtures(): boolean {
  return FIXTURE_NAMES.every((name) => existsSync(fixturePath(name)));
}
