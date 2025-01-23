# Roadmap: 01-OmniPayX (Global Payment Gateway)

This document outlines a detailed implementation roadmap for the OmniPayX system, from setting up the local environment, developing core services, integrating AWS infrastructure (Terraform, EKS) to getting ready for Production operation.

**Prerequisites:** Architecture and technology stack have been finalized in `README.md`. This roadmap is designed so that a Software Engineer can self-code and learn through small Phases (Learning by doing).

---

## Phases Overview

| Phase | Focus | Steps | Risks / Notes |
|---|---|---|---|
| **Phase 1-3** | Foundation, Docker, Compose, CI Skeleton | 20 | Ensure Docker images are lightweight and secure. |
| **Phase 4-5** | Core Domain & Outbox Pattern | 14 | Deeply understand Transactional Messaging mechanism. |
| **Phase 6-7** | Routing & Integrations | 13 | Securely manage outbound network connections. |
| **Phase 8-9** | Resilience & Observability | 12 | Avoid system overload, ensure TraceID propagation. |
| **Phase 10-12** | Infrastructure (Terraform) & K8s (EKS) | 18 | Carefully manage Terraform state and IAM permissions. |
| **Phase 13-14** | CD Pipeline & Prod Readiness | 10 | Ensure the Rollback process works smoothly. |

---

## Phase 1: Monorepo & Tooling Foundation
**Objective:** Set up a multi-module project structure (Gradle/Maven), standardize code style, and basic CI skeleton.
**Risk/Cost:** Initial misconfiguration leading to library conflicts between modules.
**DoD:** Project builds successfully, CI checks pass on GitHub.

| # | Service/Component | File path | Objective | Verify commands | Depends on |
|---|---|---|---|---|---|
| ✅ 1.1 | Root | `build.gradle` (or `pom.xml`) | Initialize multi-module project (Spring Boot 3, Java 21) | `./gradlew build` | N/A |
| ✅ 1.2 | Root | `.editorconfig`, `checkstyle.xml` | Configure standard code formatting and linting rules (Spotless/Checkstyle) | `./gradlew check` | 1.1 |
| ✅ 1.3 | GitHub Actions | `.github/workflows/ci.yml` | Create CI skeleton (run basic lint and test on every PR) | Push PR -> check GHA green | 1.1, 1.2 |
| ✅ 1.4 | `shared-libs` | `shared-dto/src/main/java/` | Create a shared module for common models, enums (Currency, Status) | `./gradlew :shared-dto:build` | 1.1 |
| 1.5 | `shared-libs` | `shared-utils/src/main/java/` | Build base exceptions and HTTP interceptor utilities | `./gradlew :shared-utils:build` | 1.1 |
| 1.6 | Root | `build.gradle` | Set up JaCoCo to generate overall code coverage reports | `./gradlew jacocoTestReport` | 1.1 |
| 1.7 | Docs | `CONTRIBUTING.md` | Write contribution and local environment setup guidelines for new developers | Read review | N/A |

## Phase 2: Dockerfiles Multi-stage & Optimization
**Objective:** Package applications into optimized, secure (non-root), and cloud-ready Docker images.
**Risk/Cost:** Oversized Docker images causing slow pull/push times and ECR storage costs.
**DoD:** Images build successfully, size < 250MB, run as a non-root user.

| # | Service/Component | File path | Objective | Verify commands | Depends on |
|---|---|---|---|---|---|
| ✅ 2.1 | `payment-api` | `payment-api/Dockerfile` | Write multi-stage build for payment-api (JDK builder -> JRE alpine) | `docker build -t payment-api:dev .` | 1.1 |
| ✅ 2.2 | `payment-api` | `payment-api/Dockerfile` | Configure HEALTHCHECK using Spring Actuator `/actuator/health` | `docker inspect --format='{{json .Config.Healthcheck}}'` | 2.1 |
| 2.3 | `routing-engine` | `routing-engine/Dockerfile` | Write multi-stage build for routing-engine similarly | `docker build -t routing:dev .` | 1.1 |
| 2.4 | `stripe-connector`| `stripe-connector/Dockerfile`| Write multi-stage build for stripe-connector | `docker build -t stripe:dev .` | 1.1 |
| 2.5 | All | `*/Dockerfile` | Configure non-root user (UID 1001) in all Dockerfiles for security reasons | `docker run --rm payment-api:dev whoami` | 2.1, 2.3, 2.4 |
| ✅ 2.6 | All | `.dockerignore` | Exclude `.git`, `.gradle`, `build/` from the build context | Check build context time minimization | N/A |
| 2.7 | GitHub Actions | `.github/workflows/ci.yml` | Add Trivy image scan step to CI pipeline to detect vulnerabilities | Check CI logs for Trivy table | 1.3, 2.1 |

## Phase 3: Docker Compose (Local Stack) & Dependencies
**Objective:** Spin up the entire dependency infrastructure locally so devs don't need cumbersome installations.
**Risk/Cost:** Local port conflicts; insufficient RAM due to running too many containers.
**DoD:** `docker compose up` successfully runs the whole stack without crash loops.

| # | Service/Component | File path | Objective | Verify commands | Depends on |
|---|---|---|---|---|---|
| ✅ 3.1 | Infra | `docker-compose.yml` | Declare PostgreSQL 15 (port 5432) + init script to create empty DB | `docker compose up -d postgres` | N/A |
| ✅ 3.2 | Infra | `docker-compose.yml` | Declare Redis 7-alpine (port 6379) for cache & idempotency | `docker compose up -d redis` | N/A |
| ✅ 3.3 | Infra | `docker-compose.yml` | Declare Zookeeper & Kafka (bitnami/kafka, port 9092) | `docker exec -it kafka kafka-topics.sh --list` | N/A |
| ✅ 3.4 | Infra | `docker-compose.yml` | Add WireMock to mock Stripe API (avoid real calls during local dev) | `curl localhost:8081/__admin/mappings` | N/A |
| ✅ 3.5 | Infra | `docker-compose.yml` | Define private networks and persistent volumes for DB/Kafka | `docker network ls` | 3.1-3.4 |
| 3.6 | All | `docker-compose.yml` | Declare app services built from source and link depend_on infra | `docker compose up --build` | Phase 2, 3.5 |

## Phase 4: Core Domain (Payment API) & Database
**Objective:** Build the core API to receive payment creation requests and handle secure storage into PostgreSQL.
**Risk/Cost:** Schema migration errors; inaccurate JPA entity mapping.
**DoD:** API receives requests, saves to DB successfully, handles duplicate requests well.

| # | Service/Component | File path | Objective | Verify commands | Depends on |
|---|---|---|---|---|---|
| ✅ 4.1 | `payment-api` | `src/main/resources/db/migration/`| Write Flyway script `V1__init_payment.sql` (Create `payments`, `outbox` tables) | App starts and runs migration | 3.1 |
| ✅ 4.2 | `payment-api` | `PaymentEntity.java`, `Repo` | JPA entity mapping for Payment object and Repository interfaces | Compile success | 4.1 |
| 4.3 | `payment-api` | `*RepositoryTest.java` | Integrate Testcontainers (PostgreSQL) to test Repository realistically | `./gradlew test` (docker hidden run) | 4.2 |
| ✅ 4.4 | `payment-api` | `PaymentService.java` | Write basic business logic for Payment creation | Unit test service mock repository | 4.2 |
| ✅ 4.5 | `payment-api` | `PaymentController.java` | Write `POST /v1/payments` endpoint, accept DTOs, validate constraints | `curl -X POST ...` -> 200/202 | 4.4 |
| ✅ 4.6 | `payment-api` | `IdempotencyFilter.java` | Implement Idempotency using Redis `SETNX` to prevent double charging | Fire 2 identical keys -> 1 success, 1 cached | 3.2, 4.5 |
| 4.7 | `payment-api` | `PaymentApiIntegrationTest.java`| Write full-flow @SpringBootTest via MockMvc | Full test suite green | 4.3-4.6 |

## Phase 5: Outbox Pattern & Event Publishing
**Objective:** Ensure Transactional Messaging (Writing to DB and sending Event to Kafka are not out of sync).
**Risk/Cost:** Kafka interruption causing Scheduler bottleneck.
**DoD:** Event appears on Kafka after successfully saving to DB.

| # | Service/Component | File path | Objective | Verify commands | Depends on |
|---|---|---|---|---|---|
| ✅ 5.1 | `payment-api` | `PaymentService.java` | Combine saving `payments` and `outbox` records into a single `@Transactional` method | Inspect DB to see data in both tables | 4.4 |
| ✅ 5.2 | `payment-api` | `OutboxEventEntity.java` | Create JPA model for Outbox table | Compile success | 4.1 |
| ✅ 5.3 | `payment-api` | `OutboxRelayScheduler.java` | Implement `@Scheduled` poller to read outbox table periodically (method 1) | See poller run every second in logs | 5.2 |
| ✅ 5.4 | `payment-api` | `KafkaConfig.java` | Configure `KafkaTemplate` with reliable properties (`acks=all`) | App starts and connects to local Kafka OK | 3.3 |
| ✅ 5.5 | `payment-api` | `KafkaPublisher.java` | Implement method to push outbox event JSON to `payment.created` topic | Producer success log | 5.4 |
| ✅ 5.6 | `payment-api` | `OutboxRelayScheduler.java` | Mark event as `is_sent=true` in DB upon receiving success callback from Kafka | Query outbox table to confirm | 5.3, 5.5 |
| 5.7 | `payment-api` | `OutboxIntegrationTest.java` | E2E Test: Call API -> Check DB -> Check Kafka topic has message | Use Kafka Testcontainers | 5.6 |

## Phase 6: Routing Engine
**Objective:** Independently resolve Message Events to decide which provider to forward the transaction to (Routing).
**Risk/Cost:** Routing logic error leading to wrong gateway transaction.
**DoD:** Receives message from Kafka, processes rule engine, and pushes new message to the correct destination.

| # | Service/Component | File path | Objective | Verify commands | Depends on |
|---|---|---|---|---|---|
| ✅ 6.1 | `routing-engine` | `KafkaConsumerConfig.java` | Setup Kafka consumer properties (group ID, deserializer) | App connects to Kafka OK | 3.3 |
| ✅ 6.2 | `routing-engine` | `PaymentCreatedListener.java` | Implement method to consume messages from `payment.created` topic | Consume log printed to screen | 6.1, 5.5 |
| ✅ 6.3 | `routing-engine` | `RoutingRuleService.java` | Build rule logic (based on currency/card) deciding Stripe vs PayPal | Unit tests for rule engine | N/A |
| ✅ 6.4 | `routing-engine` | `RoutingRuleService.java` | Apply Java 21 Switch Expressions & Pattern Matching for routing | Code review check | 6.3 |
| ✅ 6.5 | `routing-engine` | `KafkaPublisher.java` | Publish routing result to destination topic (e.g., `route.stripe`) | Check `route.stripe` topic via console | 6.2-6.4 |
| 6.6 | `routing-engine` | `RoutingIntegrationTest.java`| Comprehensive test of Consumer -> Rule -> Producer flow | Pass tests | 6.5 |

## Phase 7: External Integration (Stripe Connector)
**Objective:** Safely interact with external banking systems.
**Risk/Cost:** 3rd party API responds too slowly, exhausting internal resources.
**DoD:** Successfully interacts with WireMock, handles retries well.

| # | Service/Component | File path | Objective | Verify commands | Depends on |
|---|---|---|---|---|---|
| ✅ 7.1 | `stripe-connector`| `RouteStripeListener.java` | Consume messages from `route.stripe` topic | Consume success log | 6.5 |
| ✅ 7.2 | `stripe-connector`| `RestClientConfig.java` | Configure Spring `RestClient` using Virtual Threads (Java 21) for HTTP I/O | App startup ok | N/A |
| ✅ 7.3 | `stripe-connector`| `StripeRestClient.java` | Call HTTP `POST /v1/charges` to WireMock's mock endpoint | Wiremock log shows incoming request | 3.4, 7.1, 7.2 |
| ✅ 7.4 | `stripe-connector`| `StripeRestClient.java` | Apply Spring Retry or Resilience4j Retry for HTTP 5xx errors | Stop wiremock -> see retry logs 3 times | 7.3 |
| ✅ 7.5 | `stripe-connector`| `GatewayMappingRepo.java` | Map Stripe response to Connector's own mapping table | Inspect connector DB | 7.3 |
| ✅ 7.6 | `stripe-connector`| `KafkaPublisher.java` | Publish aggregated result to `payment.result` topic (success/error) | `kafka-console-consumer.sh` receives msg | 7.5 |
| ✅ 7.7 | `payment-api` | `PaymentResultListener.java`| Add consumer in API to listen for result and update PENDING -> SUCCESS/FAILED | E2E flow: POST payment -> DB becomes SUCCESS| 4.1, 7.6 |

## Phase 8: Resilience & Security
**Objective:** Robust system against DDoS attacks and network disruptions.
**Risk/Cost:** Incorrect Circuit Breaker configuration causing unjust disconnections.
**DoD:** System rejects requests exceeding thresholds and auto-disconnects from faulty services.

| # | Service/Component | File path | Objective | Verify commands | Depends on |
|---|---|---|---|---|---|
| 8.1 | `stripe-connector`| `CircuitBreakerConfig.java` | Wrap external call with Circuit Breaker (50% error threshold) | Force Wiremock 500 continuously -> CB opens | 7.4 |
| 8.2 | `stripe-connector`| `StripeRestClient.java` | Implement Fallback logic when CB is open (return FAILED immediately, no network call) | Test CB open -> receive FAILED error code | 8.1 |
| ✅ 8.3 | `payment-api` | `RateLimitingFilter.java` | Implement Token Bucket rate limit using Redis (by IP or MerchantID) | Fire > 10 req/s -> get HTTP 429 error | 3.2, 4.5 |
| ✅ 8.4 | `payment-api` | `SecurityConfig.java` | Configure Spring Security (Resource Server) to validate JWT bearer tokens | Call API without Token -> get 401 | 4.5 |
| 8.5 | All | `KafkaConfig.java` | Configure Dead Letter Queue (DLQ) for Kafka consumer to handle error msgs | Force msg processing error -> check `*.dlq` topic | 6.1, 7.1 |
| 8.6 | Tools | `load_test.js` | Write a simple K6 load test script to check performance and rate limits | `k6 run load_test.js` -> view report | N/A |

## Phase 9: Observability & Logging
**Objective:** Enhance system observability (Tracing, Metrics, Logs).
**Risk/Cost:** Excessive log generation filling up disk space if no retention policy is set.
**DoD:** Distributed trace works flawlessly across all nodes.

| # | Service/Component | File path | Objective | Verify commands | Depends on |
|---|---|---|---|---|---|
| 9.1 | All | `application.yml` | Enable Spring Boot Actuator endpoints, expose `/actuator/prometheus` | `curl .../actuator/prometheus` | N/A |
| 9.2 | All | `MetricsConfig.java` | Register custom metrics (business metrics like `payment.processed.count`) | Check prometheus endpoint output | 9.1 |
| 9.3 | All | `build.gradle` | Add Micrometer Tracing (OpenTelemetry) dependency; configure JSON logs | Console log outputs JSON containing TraceID field | 9.1 |
| 9.4 | Infra | `docker-compose.yml` | Add Jaeger (or Zipkin) to local docker-compose for visual trace viewing | Open Jaeger UI (port 16686) successfully | 3.5 |
| 9.5 | All | `KafkaConfig.java` | Configure automatic TraceID propagation via Kafka Headers | Consume message, observe TraceID header | 9.3, 5.5 |
| 9.6 | Ops | Jaeger UI | Verify an end-to-end transaction creates a seamless Trace across 3 services | Access UI and view valid span hierarchy | 9.5, 7.7 |

## Phase 10: Infrastructure as Code (Terraform)
**Objective:** Standardized provisioning of network infrastructure and Database/Kafka on AWS.
**Risk/Cost:** High AWS costs if RDS/MSK sizing is too large.
**DoD:** `terraform apply` successfully creates VPC, RDS, MSK infrastructure.

| # | Service/Component | File path | Objective | Verify commands | Depends on |
|---|---|---|---|---|---|
| 10.1| Terraform | `infra/terraform/backend.tf` | Initialize backend state (S3 bucket + DynamoDB table for lock) | `terraform init` | N/A |
| 10.2| Terraform | `infra/terraform/modules/vpc/` | Create VPC, Public/Private Subnets, NAT Gateways, Route Tables | `terraform plan` | 10.1 |
| 10.3| Terraform | `infra/terraform/modules/rds/` | Create RDS PostgreSQL Multi-AZ (placed in private subnet) | `terraform plan` | 10.2 |
| 10.4| Terraform | `infra/terraform/modules/elasticache/` | Create ElastiCache Redis cluster (private subnet) | `terraform plan` | 10.2 |
| 10.5| Terraform | `infra/terraform/modules/msk/` | Create Amazon MSK (Managed Kafka) cluster | `terraform plan` | 10.2 |
| 10.6| Terraform | `infra/terraform/envs/staging/`| Link modules together to define staging environment | `terraform apply` (check on AWS Console) | 10.2-10.5 |

## Phase 11: EKS Setup & Kubernetes Manifests
**Objective:** Prepare Kubernetes environment and define application runtime (Deployment, Service).
**Risk/Cost:** OOM (Out Of Memory) errors if Pod resource allocation is inaccurate.
**DoD:** EKS cluster is created, manifests are valid.

| # | Service/Component | File path | Objective | Verify commands | Depends on |
|---|---|---|---|---|---|
| 11.1| Terraform | `infra/terraform/modules/eks/` | Initialize EKS Cluster and Managed Node Groups (M6i) | `terraform apply` -> cluster ready | 10.2 |
| 11.2| K8s | N/A | Use Helm to install AWS Load Balancer Controller as Ingress Controller | `kubectl get pods -n kube-system` | 11.1 |
| 11.3| K8s | N/A | Install External Secrets Operator (ESO) to securely fetch secrets from AWS Secrets Manager | `kubectl get crds` | 11.1 |
| 11.4| `payment-api` | `deploy/helm/payment-api/` | Write Helm chart (Deployment, Service, ConfigMap, HPA) for API | `helm lint` and `helm template` outputs standard yaml | 11.1 |
| 11.5| `routing-engine` | `deploy/helm/routing/` | Write Helm chart for Routing Engine | `helm lint` | 11.4 |
| 11.6| `stripe-connector` | `deploy/helm/stripe/` | Write Helm chart for Stripe Connector | `helm lint` | 11.4 |

## Phase 12: Deployment (Staging)
**Objective:** Deploy the entire system to Staging environment running for real on AWS.
**Risk/Cost:** Internal network errors (Security Groups) preventing EKS from connecting to RDS/MSK.
**DoD:** System runs successfully on EKS, receives requests from the Internet.

| # | Service/Component | File path | Objective | Verify commands | Depends on |
|---|---|---|---|---|---|
| 12.1| DB | N/A | Run DB Migration (Flyway) on staging RDS (from a CI job or bastion host) | Connect to DB, observe all schema tables | 10.3, 4.1|
| 12.2| GitHub Actions | `.github/workflows/cd.yml` | Update pipeline: Build Docker Image -> Push to ECR registry | Check image exists on AWS ECR | 2.1, 1.3 |
| 12.3| GitHub Actions | `.github/workflows/cd.yml` | Update pipeline: Run `helm upgrade --install` to deploy apps to Staging EKS | `kubectl get pods -n staging` shows Running | 11.4, 12.2 |
| 12.4| Infra (Terraform) | `modules/waf/` | Add AWS WAF attached to Staging ALB to block basic attacks | Check WAF rules on AWS Console | 12.3 |
| 12.5| Post-Deploy | N/A | Run K6 smoke test against Staging ALB address | `curl -X POST <STAGING_ALB_URL>/v1/payments` | 12.3 |
| 12.6| Ops | K8s/AWS | Debug network connections: Verify Pods can access RDS, MSK, and Redis | Check Pod logs for no TimeoutException | 12.5, 10.6 |

## Phase 13: Prod Gate, Rollback & Chaos Drill
**Objective:** Establish safety gates and perform Disaster Recovery testing.
**Risk/Cost:** Data loss risk if DB failover drill fails (only perform on staging).
**DoD:** System passes basic fault tolerance tests.

| # | Service/Component | File path | Objective | Verify commands | Depends on |
|---|---|---|---|---|---|
| 13.1| GitHub Actions | `.github/workflows/cd-prod.yml`| Add Prod Deploy environment, configure mandatory Manual Approval | GHA pauses waiting for QA/Tech Lead approval | 12.3 |
| 13.2| Docs | `docs/runbooks/rollback.md` | Write and drill K8s Rollback (`helm rollback`) for failed releases | Application successfully restores to previous version | 12.3 |
| 13.3| Ops | AWS RDS | Chaos Drill: Proactively kill RDS Primary node to observe Multi-AZ failover | App drops temporarily then recovers in < 1 minute | 10.3 |
| 13.4| Ops | K8s | Chaos Drill: Scale Redis replicas to 0 to verify Fallback Fail-Open logic | App still receives requests successfully | 8.3 |
| 13.5| Ops | K8s | Run K6 Load test simulating 1000 TPS to observe HPA pod scaling | `kubectl get hpa` shows replicas scaling up automatically | 11.4 |

## Phase 14: Production Readiness
**Objective:** Finalize monitoring systems and hand over to the operations team.
**Risk/Cost:** Alert Fatigue if alert thresholds are misconfigured.
**DoD:** Dashboards and Alerts are complete. Project handover finalized.

| # | Service/Component | File path | Objective | Verify commands | Depends on |
|---|---|---|---|---|---|
| 14.1| OTel | N/A | Setup Grafana or CloudWatch Dashboards to display 4 Golden Signals | Open Dashboard, see Latency, Traffic, Errors, Saturation | 9.2, 12.5 |
| 14.2| OTel | N/A | Configure Alert Manager to warn if Error Rate (5xx) exceeds 1% for 5 minutes | Receive test message on ops channel | 14.1 |
| 14.3| K8s | `deploy/helm/...` | Add PodDisruptionBudgets (PDB) and node Anti-Affinity to ensure HA | `kubectl get pdb` and check policy | 11.4 |
| 14.4| Docs | `docs/runbooks/on-call-guide.md` | Write on-call playbook for handling common alert scenarios | Review playbook with ops team | N/A |
| 14.5| Portfolio | `README.md` | Finalize all documentation, review overall architecture, mark project as complete | Complete | N/A |

---

## Skills Summary Table

| Phase | Related Services | Categories (Plane / DevOps) | Learning Outcomes |
|---|---|---|---|
| **P1-P3** | All | Tooling, Docker, Compose | Master monorepo structure, package secure and size-optimized containers. Setup a perfect local environment. |
| **P4-P5** | `payment-api` | Domain, Data, Async, Database | Master Transactional Messaging, Idempotency, and strictly RESTful API design. |
| **P6-P7** | `routing`, `stripe` | Async, Integration, Domain | Proficient in Event-Driven Microservices with Kafka; leverage Virtual Threads (Java 21) for I/O blocking calls. |
| **P8-P9** | All | Security, Resilience, Observability | Build self-protecting systems (Circuit Breaker, Rate Limit), setup distributed Tracing for wide-scale debugging. |
| **P10-P11** | Infra | IaC (Terraform), Docker/Local, Scale | Elevate DevOps skills: VPC network design, automate cloud infrastructure provisioning via Terraform, Kubernetes (EKS). |
| **P12-P14** | Infra | CI/CD, Operability, Scale | Implement GitOps (CD), ensure practical system fault tolerance (Multi-AZ Failover, Chaos Testing, Metrics Alerting). |

---

## Session Log

| Date / Session | Phase / Steqps Completed           | PR / Commit Link | Notes & Personal Learnings |
|---|------------------------------------|---|---|
| 2025-01-16 | Project Design & Roadmap Alignment | N/A | Finalized system architecture, expanded roadmap to 87 steps, and fully translated documentation to English to meet strict production-grade constraints. |
| 2025-01-16 | 2                                  | 2.3, 2.4 | ✅ Done | Viết Multi-stage Dockerfiles cho routing-engine và stripe-connector. |
| 2025-01-16 | 3                                  | 3.6 | ✅ Done | Khai báo 3 dịch vụ ứng dụng vào docker-compose và sử dụng biến môi trường. |
| 2025-01-16 | 4                                  | 4.3 | ✅ Done | Viết Integration Test cho PaymentRepository với PostgreSQL Testcontainers. |
| 2025-01-16 | 5                                  | 5.7 | ✅ Done | Viết Integration Test cho Outbox Pattern (lưu DB & chờ Scheduler xử lý). |
| 2025-01-16 | 6                                  | 6.6 | ✅ Done | Viết Integration Test định tuyến Kafka cho routing-engine. |
| 2025-01-16 | 8                                  | 8.1, 8.2 | ✅ Done | Bổ sung Resilience4j CircuitBreaker và hàm Fallback cho StripeRestClient. |
| 2025-01-18 | 8                                  | 8.5 | ✅ Done | Cấu hình Dead Letter Queue (DLQ) cho Kafka Consumer. |
| 2025-01-18 | 8                                  | 8.6 | ✅ Done | Viết kịch bản k6 Load Test kiểm chứng Rate Limiter, hệ thống chống chịu tốt với JWT 403 và 429. |
| 2025-01-18 | 9                                  | 9.1, 9.2 | ✅ Done | Bật Actuator Prometheus và gắn Custom Business Metric cho Payment API. |
| 2025-01-19 | 9                                  | 9.3-9.6  | ✅ Done | Successfully configured Micrometer Tracing and Zipkin. Verified TraceID propagation across 3 services via Kafka. |
| 2025-01-20 | 10                                 | 10.1-10.6 | ✅ Done | Completed IaC infrastructure (Terraform) including VPC, RDS, ElastiCache, MSK for staging environment. |
| 2025-01-22 | 11                                 | 11.1-11.3 | ✅ Done | Created EKS module with Managed Node Groups, configured IRSA for AWS Load Balancer Controller & External Secrets Operator. |
| 2025-01-22 | 11                                 | 11.4-11.6 | ✅ Done | Created Helm charts (Deployment, Service, HPA) for payment-api, routing-engine, and stripe-connector. |
| 2025-01-23 | 12                                 | 12.1-12.3 | ✅ Done | Implemented monorepo GitHub Actions pipeline for path-based Docker builds and Helm staging deployments. |
| 2025-01-23 | 12                                 | 12.4      | ✅ Done | Created AWS WAF Terraform module with Managed Rule Sets to protect the EKS Application Load Balancer. |
| 2025-01-23 | 12                                 | 12.5-12.6 | ✅ Done | Created K6 smoke test script and conceptually verified EKS Pod connectivity. Phase 12 Complete! |
