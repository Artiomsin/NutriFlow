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

This starts PostgreSQL 16 on `localhost:5432`, MinIO on `localhost:9000`, and
Valkey on `localhost:6379`, applies migrations, and runs unit, integration,
and E2E tests. All of these
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

`test:integration` uses Valkey to verify the Redis integration. Unit tests and
the optional real-AI evaluation do not require a running Redis server.

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
RATE_LIMIT_BARCODE=30
ANALYSIS_DAILY_LIMIT=6
```

The API limits ordinary requests to 120 per minute per IP, authentication to
10 per 15 minutes per IP, refreshes to 30 per minute per IP, uploads to 10 per
minute per user, food analysis to 3 per minute plus its daily quota, and
barcode lookups to 30 per minute per user and per IP. The Render health
endpoints are excluded from throttling.

## Barcode lookups

`GET /foods/barcode/:barcode` resolves a scanned GTIN in this order:

1. the user's own products and the shared catalog (one indexed query);
2. Open Food Facts, an external public database;
3. a Redis cache in front of both, enabled while a cacheable external
   provider is registered.

Configuration:

```env
OFF_ENABLED=true
OFF_API_URL=https://world.openfoodfacts.org
OFF_TIMEOUT_MS=5000
OFF_REQUESTS_PER_MINUTE=15
OFF_USER_AGENT=NutriFlow/1.0 (https://nutriflow.app; contact@nutriflow.app)
```

Open Food Facts needs **no API key for reads**. Requests must carry a
descriptive `User-Agent`, and product reads are limited to 15 per minute per
server IP. `OFF_REQUESTS_PER_MINUTE` is a per-process budget, so divide it by
the number of API instances that share one egress IP.

Responses use `400` for an invalid GTIN, `404` when the barcode is valid but
unknown, and `503` when a provider could not be reached. A miss caused by a
provider outage is never cached as "not found".

Product data from Open Food Facts is licensed under the Open Database License
(ODbL) and its images under CC BY-SA. Clients that display OFF data must
attribute Open Food Facts and keep derivative data share-alike.

To stop the test database:

```bash
bun run test:db:down
```

To delete its data and start from a clean database on the next run:

```bash
bun run test:db:reset
```
