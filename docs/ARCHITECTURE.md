# Architecture: OmniPayX

## Actual Architecture (Current State)

```mermaid
C4Context
    title OmniPayX - Current Container Diagram
    Person(user, "Merchant / Client", "Sends payment requests")
    System_Boundary(c1, "OmniPayX Core") {
        Container(paymentApi, "Payment API", "Java 21, Spring Boot", "Receives request, Auth, Rate Limit (WAF/Redis)")
        Container(routingEngine, "Routing Engine", "Java 21", "Evaluates routing rules")
        Container(stripeConn, "Stripe Connector", "Java 21", "Integrates with Stripe")
        ContainerDb(pgCore, "PostgreSQL", "RDS Multi-AZ", "Payment State & Outbox Table")
        ContainerDb(redisCore, "Redis", "ElastiCache", "Idempotency & Rate Limiting")
        ContainerDb(kafka, "Event Bus", "MSK", "Kafka Topics: payment.created, route.stripe, payment.result")
    }
    System_Ext(stripe, "Stripe API", "External Payment Provider")
    System_Ext(waf, "AWS WAF", "Application Firewall")
    System_Ext(alb, "AWS ALB", "Load Balancer")

    Rel(user, waf, "POST /v1/payments (REST)")
    Rel(waf, alb, "Forward Traffic")
    Rel(alb, paymentApi, "Ingress Route")
    
    Rel(paymentApi, redisCore, "Check Idempotency")
    Rel(paymentApi, pgCore, "Insert Payment & Outbox")
    Rel(paymentApi, kafka, "Publish [payment.created]")
    
    Rel(kafka, routingEngine, "Consume [payment.created]")
    Rel(routingEngine, kafka, "Publish [route.stripe]")
    
    Rel(kafka, stripeConn, "Consume [route.stripe]")
    Rel(stripeConn, stripe, "POST /v1/charges")
    Rel(stripeConn, kafka, "Publish [payment.result]")
    
    Rel(kafka, paymentApi, "Consume [payment.result]")
    Rel(paymentApi, pgCore, "Update Payment Status")
```

## Spec vs Actual

| Component | Per README/02 | Actual in code | Reason for divergence |
|---|---|---|---|
| AWS Infrastructure | High-level Terraform modules | Raw AWS resources in Terraform | Preference for granular control and explicit understanding of the infrastructure components. |
| IAM Auth (Cognito/OAuth2) | Validate Token via IAM | Skipped/Mocked in API | To focus on Core Payment routing logic and infrastructure deployment within the roadmap timeframe. |
| CDC Engine (Debezium) | Debezium polling Outbox | Simplified Spring Scheduler | Kept within Java service bounds to reduce operational overhead for a portfolio project, while maintaining the Outbox Pattern concept. |
| PayPal Connector | Planned `paypal-connector` | Not implemented | Scope control. Stripe was sufficient to prove the routing and event-driven architecture. |

## Bounded Contexts & Module Boundaries

1. **Payment Core (`payment-api`):** Owns the `Payment` and `Transaction` entities. Strictly an edge service. It never calls downstream services synchronously. All cross-boundary communication is done by emitting `payment.created` and consuming `payment.result`.
2. **Routing (`routing-engine`):** A stateless rules engine that listens to payments and decides the destination. Entirely decoupled from the Edge and the Connectors.
3. **Gateway Integration (`stripe-connector`):** Responsible for translating internal domain events to Stripe API contracts. Implements its own retry policies and circuit breakers (Resilience4j).

## Known Gaps / Architectural TODOs

1. **Authentication:** OAuth2/JWT validation is currently a stub. A real Identity Provider (Cognito or Keycloak) needs to be integrated.
2. **Debezium Integration:** True CDC (Change Data Capture) via Debezium + Kafka Connect is needed to completely eliminate the Spring `@Scheduled` outbox polling and ensure strict exactly-once semantics.
3. **Multi-Region Active-Active:** Currently deployed in a single Region (us-east-1) across multiple AZs. Multi-region failover via Route53 and RDS Cross-Region Replication is documented but not fully provisioned in Terraform.
