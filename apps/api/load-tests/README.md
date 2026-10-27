# API load testing with k6

These scenarios measure API behaviour under load. They are not Bun tests and
are never part of the regular test suite or CI: they require a running API.
Each completed scenario automatically appends its metrics to
`docs/load-testing.md`; its full k6 JSON summary stays in
`load-tests/results/` locally and is not committed.

## Install k6

On macOS:

```bash
brew install k6
```

## Required environment

Each run creates an isolated account and profile for every virtual user through
the normal API, then deletes them through `DELETE /api/users/me` in teardown.
Never use a personal or production customer account.

```bash
export BASE_URL=http://127.0.0.1:3000
export LOAD_TEST_RUN_ID=20261027-01
export LOAD_TEST_PASSWORD='a-long-test-only-password'
export ALLOW_LOAD_TEST_PROVISIONING=true
```

Remote targets are blocked by default. A remote run is allowed only when both
the target is a dedicated staging environment and this explicit acknowledgement
is set:

```bash
export BASE_URL=https://staging-api.example.com
export ALLOW_REMOTE_LOAD_TEST=true
export ALLOW_LOAD_TEST_PROVISIONING=true
```

Do not set `ALLOW_REMOTE_LOAD_TEST=true` for an environment with real customer
data.

The scripts generate emails such as `load-20261027-01-001@load-test.invalid`.
Set `LOAD_TEST_USER_COUNT` only for `load:cleanup`; it must equal the largest
virtual-user count used by the interrupted run. It can also be set before a
run to provision more accounts than the peak VU count.

## Scenarios

```bash
bun run load:smoke   # one authenticated end-to-end read pass
bun run load:read    # 10 → 25 virtual users, configurable with LOAD_PEAK_VUS
bun run load:food-search # 1 → 5 virtual users; cached external USDA catalog search
# Five concurrent cold AI analyses, then a cached repeat for each user.
bun run load:food-analysis
bun run load:write   # 1 → 5 virtual users; water and food-entry write/update/delete cycle
bun run load:upload  # one upload and authorised private-file read
bun run load:cleanup # remove accounts left by an interrupted run
```

`load:upload` intentionally runs once. Its test account is deleted in teardown;
the existing backend storage cleanup queue then removes the private object.
If k6 is interrupted, run `load:cleanup` with the same `LOAD_TEST_RUN_ID`.

`load:food-analysis` uses five test users and five distinct fixtures. Each user
first submits a different image (five real provider calls), then immediately
repeats that same image to verify the per-user cache. It must run only on a
local or dedicated staging target with `RATE_LIMIT_ANALYZE=15` or higher. It
uses external AI quota; run it at most once per test environment and do not
increase its VU count.

## Interpreting a run

Start with `load:smoke`, then `load:read`, `load:food-search`, and only then
`load:write`. `load:read` measures only internal API and database work.
`load:food-search` measures the USDA-enriched search path separately; its
first cache miss may return local results while USDA is unavailable. Smoke
checks functional connectivity only; use the read, food-search, and write
flows for latency thresholds. Record
the k6 `http_req_duration` p95/p99, `http_req_failed`, RPS, Render CPU/RAM,
Neon connections/query latency, and Valkey memory. Initial release targets are
an error rate below 1%, p95 below 1.2 seconds for reads and 1.5 seconds for
writes. Stop a stress run if sustained 5xx responses, memory pressure, or
database connection saturation appear.

## Rate limits

Capacity tests intentionally create multiple users. On local or dedicated
staging only, set high temporary values such as `RATE_LIMIT_GLOBAL=1000` and
`RATE_LIMIT_AUTH=100` before starting the API. `load:food-analysis` also
requires `RATE_LIMIT_ANALYZE=15`. Otherwise the test measures the intended
anti-abuse limits rather than API capacity. Do not change those limits in
production; test production rate limiting separately with 1–2 VUs.
