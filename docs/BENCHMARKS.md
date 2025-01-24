# Benchmarks & Load Testing

## Target vs Actual

| Metric | Target (SLO/Traffic Profile) | Actual measured | Gap | Note |
|---|---|---|---|---|
| Steady Write Traffic (TPS) | 2,000 TPS | ⚠️ Not measured | N/A | Need to run `tests/load_test_prod.js` |
| Peak Write Traffic (TPS) | 10,000 TPS | ⚠️ Not measured | N/A | Need to run `tests/load_test_prod.js` |
| P99 Latency (Create Payment) | < 500ms | ⚠️ Not measured | N/A | Need to run `tests/load_test_prod.js` |
| Error Rate | < 1% | ⚠️ Not measured | N/A | Need to run `tests/load_test_prod.js` |
| Pod Autoscaling (HPA) | Scale on CPU > 70% | ⚠️ Not measured | N/A | Need to run `tests/load_test_prod.js` |

## Methodology

A K6 load testing script (`tests/load_test_prod.js`) has been prepared to simulate up to 1000 TPS.

**Command to run the benchmark:**
```bash
# Ensure K6 is installed, then run:
export PROD_URL="http://<your-alb-dns-name>"
k6 run tests/load_test_prod.js
```

## Known Bottlenecks (Theoretical)
- **Outbox Poller:** If the Spring `@Scheduled` task pulls too many records at once without pagination, it will cause OOM (Out of Memory) or block the DB.
- **PostgreSQL Connections:** Without a connection pooler like PgBouncer, 1000 TPS might exhaust the maximum connections allowed by the RDS instance type.
