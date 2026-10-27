# Load-testing results

Each completed k6 run appends one row here automatically. Do not include
credentials, tokens, or customer data.

| Date | Environment | Scenario | Peak VU | RPS | p95 | p99 | Error rate | Render CPU/RAM | Neon/Valkey notes | Result |
|---|---|---|---:|---:|---:|---:|---:|---|---|---|
| 2026-10-27 | 127.0.0.1:3000 | write | 20 | — | — | — | — | local / n/a | Auto-recorded; see raw k6 summary locally | Failed (k6 107) |

| 2026-10-27 | 127.0.0.1:3000 | write | 20 | — | — | — | — | local / n/a | Auto-recorded; see raw k6 summary locally | Failed (k6 99) |

| 2026-10-27 | 127.0.0.1:3000 | upload | 1 | — | — | — | — | local / n/a | Auto-recorded; see raw k6 summary locally | Passed |

## Release criteria

- Read flow: error rate below 1%, p95 below 1.2 seconds.
- Write flow: error rate below 1%, p95 below 1.5 seconds.
- No sustained 5xx responses, Render memory pressure, Neon connection
  saturation, or Valkey memory exhaustion.
- All generated test users are removed; after upload tests, verify the storage
  cleanup queue has completed.
