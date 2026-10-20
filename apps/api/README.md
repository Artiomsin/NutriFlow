# NutriFlow API

Install dependencies:

```bash
bun install
```

## Local test database

Tests use local PostgreSQL and MinIO (S3-compatible) containers and never need
Neon or real S3 credentials.
Start Docker Desktop or OrbStack, then run:

```bash
bun run test
```

This starts PostgreSQL 16 on `localhost:5432` and MinIO on `localhost:9000`,
applies migrations, and runs unit, integration, and E2E tests. All of these
commands force the Docker test database and storage URLs, so they cannot
connect to Neon or real S3.

To start the database without running tests:

```bash
bun run test:db:up
```

Run a specific test group after the database is running:

```bash
bun run test:unit
bun run test:integration
bun run test:e2e
```

The AI evaluation is separate because it uses real provider API quota:

```bash
bun run test:ai
```

## Rate limits

Rate-limit counters and the daily AI-analysis quota are stored in PostgreSQL,
so they survive Render restarts and deployments. Apply the included migration
before deploying this change:

```bash
bun run migrate
```

Set the same values in local `.env` and Render Environment:

```env
TRUST_PROXY=1
RATE_LIMIT_GLOBAL=120
RATE_LIMIT_AUTH=10
RATE_LIMIT_REFRESH=30
RATE_LIMIT_UPLOAD=10
RATE_LIMIT_ANALYZE=3
ANALYSIS_DAILY_LIMIT=6
```

The API limits ordinary requests to 120 per minute per IP, authentication to
10 per 15 minutes per IP, refreshes to 30 per minute per IP, uploads to 10 per
minute per user, and food analysis to 3 per minute plus its daily quota. The
Render health endpoints are excluded from throttling.

To stop the test database:

```bash
bun run test:db:down
```

To delete its data and start from a clean database on the next run:

```bash
bun run test:db:reset
```
