import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import { resolve } from 'node:path';

type Scenario = keyof typeof scenarios;

type K6Metric = {
  values?: Record<string, number>;
};

type K6Summary = {
  metrics?: Record<string, K6Metric>;
};

const apiRoot = resolve(import.meta.dir, '..');
const repositoryRoot = resolve(apiRoot, '../..');
const resultsDirectory = resolve(apiRoot, 'load-tests/results');
const resultsDocument = resolve(repositoryRoot, 'docs/load-testing.md');

const scenarios = {
  smoke: { script: 'load-tests/smoke.js', defaultPeakVus: 1 },
  read: { script: 'load-tests/read-flow.js', defaultPeakVus: 25 },
  'food-search': {
    script: 'load-tests/food-search-flow.js',
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

function metric(
  summary: K6Summary,
  name: string,
  value: string,
): number | null {
  const result = summary.metrics?.[name]?.values?.[value];
  return typeof result === 'number' && Number.isFinite(result) ? result : null;
}

function formatDuration(milliseconds: number | null): string {
  if (milliseconds === null) return '—';
  if (milliseconds >= 1_000) return `${(milliseconds / 1_000).toFixed(2)}s`;
  return `${milliseconds.toFixed(0)}ms`;
}

function formatRate(rate: number | null, decimals = 2): string {
  return rate === null ? '—' : `${(rate * 100).toFixed(decimals)}%`;
}

function configuredEnvironment(): string {
  const baseUrl = process.env.BASE_URL ?? 'http://127.0.0.1:3000';
  try {
    return new URL(baseUrl).host;
  } catch {
    return baseUrl;
  }
}

async function recordResult(
  summaryPath: string,
  scenario: Scenario,
  peakVus: number,
  exitCode: number,
): Promise<void> {
  const summary = JSON.parse(await readFile(summaryPath, 'utf8')) as K6Summary;
  const rps = metric(summary, 'http_reqs', 'rate');
  const p95 = metric(summary, 'http_req_duration', 'p(95)');
  const p99 = metric(summary, 'http_req_duration', 'p(99)');
  const errorRate = metric(summary, 'http_req_failed', 'rate');
  const result = exitCode === 0 ? 'Passed' : `Failed (k6 ${exitCode})`;
  const row = [
    new Date().toISOString().slice(0, 10),
    configuredEnvironment(),
    scenario,
    String(peakVus),
    rps === null ? '—' : rps.toFixed(2),
    formatDuration(p95),
    formatDuration(p99),
    formatRate(errorRate),
    'local / n/a',
    'Auto-recorded; see raw k6 summary locally',
    result,
  ];
  const markdownRow = `| ${row.join(' | ')} |`;
  const document = await readFile(resultsDocument, 'utf8');
  const placeholder = '| — | — | — | — | — | — | — | — | — | — | Not run |';
  const updated = document.includes(placeholder)
    ? document.replace(placeholder, markdownRow)
    : document.replace(/\n(## Release criteria)/, `\n${markdownRow}\n\n$1`);

  await writeFile(resultsDocument, updated);
}

async function main(): Promise<void> {
  const scenario = process.argv[2] as Scenario | undefined;
  if (!scenario || !(scenario in scenarios)) {
    throw new Error(`Choose one of: ${Object.keys(scenarios).join(', ')}`);
  }

  const runId = requiredRunId();
  const definition = scenarios[scenario];
  const requestedPeak = Number(
    process.env.LOAD_PEAK_VUS ?? definition.defaultPeakVus,
  );
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

  try {
    await recordResult(summaryPath, scenario, requestedPeak, exitCode);
    console.log(`Recorded result in ${resultsDocument}`);
  } catch (error) {
    console.error(`Could not record load-test result: ${String(error)}`);
  }

  process.exit(exitCode);
}

await main();
