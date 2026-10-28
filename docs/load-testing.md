# Load-testing results

Record only reviewed, release-relevant k6 runs here manually. Raw local k6
summaries are ignored in `apps/api/load-tests/results/`. Do not include
credentials, tokens, or customer data.

| Date | Environment | Scenario | Peak VU | RPS | p95 | p99 | Error rate | Render CPU/RAM | Neon/Valkey notes | Result |
|---|---|---|---:|---:|---:|---:|---:|---|---|---|
| — | — | — | — | — | — | — | — | — | — | Not run |

## Release criteria

- Read flow: error rate below 1%, p95 below 1.2 seconds.
- Write flow: error rate below 1%, p95 below 1.5 seconds.
- No sustained 5xx responses, Render memory pressure, Neon connection
  saturation, or Valkey memory exhaustion.
- All generated test users are removed; after upload tests, verify the storage
  cleanup queue has completed.
