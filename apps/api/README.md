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

To stop the test database:

```bash
bun run test:db:down
```

To delete its data and start from a clean database on the next run:

```bash
bun run test:db:reset
```
