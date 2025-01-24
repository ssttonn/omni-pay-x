# Playbook: On-Call Guide & Monitoring

**Objective:** Provide immediate resolution paths for on-call engineers when automated alerts are triggered.

## The 4 Golden Signals

We monitor the system using the 4 Golden Signals:
1. **Latency:** The time it takes to service a request.
2. **Traffic:** A measure of how much demand is being placed on the system.
3. **Errors:** The rate of requests that fail.
4. **Saturation:** How "full" the system is (CPU, Memory).

---

## Alert: High Error Rate (> 1% 5xx Errors)
**Symptom:** The `payment-api` is returning HTTP 500s.

**Resolution Steps:**
1. Check Zipkin / Jaeger tracing to see if the failure originates in the `payment-api` itself, or if a downstream service (`routing-engine` or `stripe-connector`) is failing.
2. If the issue is downstream (e.g. Stripe is down), verify that the Circuit Breaker has opened. If it hasn't, consider forcing the circuit breaker open manually via Spring Boot Admin.
3. Check the Dead Letter Queues (DLQ) in Kafka. If messages are piling up, the consumers are failing. Investigate the application logs for `NullPointerException` or deserialization errors.

## Alert: High Latency (> 2000ms p99)
**Symptom:** Requests are taking too long to complete.

**Resolution Steps:**
1. Check RDS CPU Utilization and Database Connections. If the DB is saturated, connections will pool and block HTTP threads.
2. If using Virtual Threads (Java 21), ensure that no synchronized blocks in older libraries are "pinning" the virtual threads.
3. Check if ElastiCache (Redis) latency has spiked. A slow cache can drastically impact the Idempotency filter.

## Alert: High Saturation (Pod Memory > 90%)
**Symptom:** Pods are approaching OOM (Out Of Memory) limits and risk being killed.

**Resolution Steps:**
1. Check the HPA (Horizontal Pod Autoscaler). Is it scaling up? If `maxReplicas` is reached, you may need to manually increase the limit in `values.yaml`.
2. Inspect the application logs for a memory leak. A sudden spike in heap usage often corresponds to pulling too many records from the database at once (e.g., the Outbox Poller fetching 100,000 records instead of 1,000).
