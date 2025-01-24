# Learnings & Self-Assessment

## Skill Assessment

- **Areas of Strength:** 
  - Designing a highly decoupled, event-driven microservices architecture using Kafka and the Outbox Pattern.
  - Applying Domain-Driven Design (DDD) to establish clear Bounded Contexts.
  - Setting up resilient CI/CD pipelines using GitHub Actions, combining path-based filtering with Helm deployments.
- **Areas for Improvement:** 
  - Writing raw Terraform without modules was verbose and prone to security group configuration errors. I relied on reference examples for the EKS IRSA (IAM Roles for Service Accounts) setup.
  - Managing Kafka consumer offsets and DLQ (Dead Letter Queue) edge cases requires deeper hands-on practice in a live failure scenario.

## Mastery Checklist

| Skill | Demonstrated In |
|---|---|
| **Java 21 Virtual Threads** | `payment-api` application properties and HTTP client configuration. |
| **Distributed Transactions (Outbox)** | `payment-api` integration tests and `PaymentRepository`. |
| **Circuit Breaker (Resilience4j)** | `stripe-connector` REST client fallback methods. |
| **Kubernetes HA (PDB, Affinity)** | `deploy/helm/*/templates/pdb.yaml` and `deployment.yaml`. |
| **Infrastructure as Code (Terraform)** | `infra/terraform/` (Raw AWS resources for VPC, EKS, RDS, MSK). |
| **Automated Testing** | `payment-api` (Testcontainers with Postgres) and `tests/smoke_test.js`. |

## Key Trade-Offs Chosen
1. **Simplified Outbox Polling vs Debezium:** We chose a Spring-based `@Scheduled` poller over Debezium to reduce infrastructure overhead (avoiding Kafka Connect) at the cost of slight latency and CPU overhead on the API pods.
2. **Raw Terraform vs AWS Modules:** We opted for raw Terraform resources to demonstrate core understanding, trading off development speed and conciseness.
3. **Manual Approval Prod Gate vs Continuous Deployment:** We prioritized safety over speed by enforcing a manual GitHub Environment gate for Production deployments.

## Industry Practice Comparison
- **Event-Driven Payments:** Using Kafka to decouple the Edge API from the Payment Gateways is standard practice for Tier-1 systems at companies like Uber and Stripe.
- **Idempotency with Redis:** Utilizing Redis `SETNX` for distributed idempotency before hitting the database is highly aligned with industry best practices to prevent double-charging during network retries.

## What I Would Do Differently
- If starting over, I would adopt **ArgoCD (GitOps)** for Kubernetes deployments instead of pushing Helm upgrades directly from GitHub Actions. ArgoCD provides better drift detection and simplifies rollbacks.
- I would implement **PgBouncer** from day one to protect the RDS instance from connection exhaustion during load spikes.

## Remaining Production Risks
- **No Secret Rotation:** Secrets (DB passwords, Stripe API keys) are currently static. We need to implement automatic rotation via AWS Secrets Manager.
- **Lack of Chaos Testing in Prod:** While we documented Chaos Drills for Staging, we have not tested how the system behaves under partial failure in Production (e.g., cross-AZ latency spikes).
