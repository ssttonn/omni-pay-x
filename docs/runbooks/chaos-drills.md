# Playbook: Chaos Drills & Disaster Recovery

**Objective:** Verify the fault tolerance of OmniPayX by purposefully introducing failures in a controlled environment (Staging).

> [!WARNING]
> Do NOT execute these drills in the Production environment unless it is a coordinated Game Day with all stakeholders.

---

## Drill 1: RDS Primary Failover (Phase 13.3)
**Hypothesis:** If the primary PostgreSQL instance in RDS crashes, AWS will automatically fail over to the Multi-AZ standby instance. The API should experience a brief blip (under 60 seconds) and then resume normal operations without manual intervention.

### Execution:
1. Open the AWS Console -> RDS.
2. Select the `omnipayx-staging-db` instance.
3. Click **Actions -> Reboot**.
4. Check the box for **Reboot With Failover**.
5. Click **Confirm**.

### Verification:
- Observe the K6 load test output. You should see a spike in `500 Internal Server Error` or timeouts for approximately 30-60 seconds.
- After 60 seconds, the errors should drop to 0 and the API should process requests successfully again.

---

## Drill 2: Redis Outage / Fail-Open (Phase 13.4)
**Hypothesis:** Redis is used for idempotency and rate limiting. If Redis goes down, the application's circuit breakers should trigger a fallback (Fail-Open) so that payments continue to be processed (though idempotency guarantees may be temporarily degraded).

### Execution:
To simulate an outage from the perspective of the application, we can temporarily block the security group, or (if running inside Kubernetes) scale a local Redis replica to 0.
Since we use ElastiCache, we can modify the application's configmap to point to an invalid Redis URL, or use a Chaos Mesh network fault.

```bash
# Using Chaos Mesh (if installed)
kubectl apply -f - <<EOF
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: redis-delay
  namespace: staging
spec:
  action: delay
  mode: all
  selector:
    labelSelectors:
      app: payment-api
  delay:
    latency: '10s'
    correlation: '100'
    jitter: '0ms'
EOF
```

### Verification:
- The application logs should show `RedisConnectionFailureException`.
- Resilience4j Circuit Breaker should open.
- The Fallback method should execute, allowing the request to proceed.
- Remove the chaos experiment to restore normalcy: `kubectl delete networkchaos redis-delay -n staging`.
