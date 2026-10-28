import { mkdir } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import { resolve } from 'node:path';

type Scenario = keyof typeof scenarios;

const apiRoot = resolve(import.meta.dir, '..');
const resultsDirectory = resolve(apiRoot, 'load-tests/results');

const scenarios = {
  smoke: { script: 'load-tests/smoke.js', defaultPeakVus: 1 },
  read: { script: 'load-tests/read-flow.js', defaultPeakVus: 25 },
  'food-search': {
    script: 'load-tests/food-search-flow.js',
    defaultPeakVus: 5,
  },
  'food-analysis': {
    script: 'load-tests/food-analysis-flow.js',
    defaultPeakVus: 5,
  },
  write: { script: 'load-tests/write-flow.js', defaultPeakVus: 5 },
  upload: { script: 'load-tests/upload-smoke.js', defaultPeakVus: 1 },
} as const;

function requiredRunId(): string {
  const runId = process.env.LOAD_TEST_RUN_ID?.trim();
  if (!runId || !/^[a-z0-9-]{3,40}$/i.test(runId)) {
    throw new Error(
      'LOAD_TEST_RUN_ID is required and must contain only letters, numbers, and hyphens.',
    );
  }
  return runId.toLowerCase();
}

async function main(): Promise<void> {
  const scenario = process.argv[2] as Scenario | undefined;
  if (!scenario || !(scenario in scenarios)) {
    throw new Error(`Choose one of: ${Object.keys(scenarios).join(', ')}`);
  }

  const runId = requiredRunId();
  const definition = scenarios[scenario];
  const requestedPeak =
    scenario === 'food-analysis'
      ? 5
      : Number(process.env.LOAD_PEAK_VUS ?? definition.defaultPeakVus);
  if (!Number.isInteger(requestedPeak) || requestedPeak < 1) {
    throw new Error('LOAD_PEAK_VUS must be a positive integer.');
  }

  await mkdir(resultsDirectory, { recursive: true });
  const summaryPath = resolve(resultsDirectory, `${runId}-${scenario}.json`);
  const exitCode = await new Promise<number>((resolveExit, reject) => {
    const child = spawn(
      'k6',
      ['run', `--summary-export=${summaryPath}`, definition.script],
      { cwd: apiRoot, env: process.env, stdio: 'inherit' },
    );
    child.once('error', reject);
    child.once('close', (code) => resolveExit(code ?? 1));
  });

  console.log(`Raw k6 summary saved to ${summaryPath}`);

  process.exit(exitCode);
}

await main();
