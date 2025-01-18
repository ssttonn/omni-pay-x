# Roadmap: 01-OmniPayX (Global Payment Gateway)

Tài liệu này vạch ra lộ trình triển khai chi tiết cho hệ thống OmniPayX, từ khâu thiết lập môi trường cục bộ, phát triển các service cốt lõi, tích hợp hạ tầng AWS (Terraform, EKS) cho đến khi sẵn sàng vận hành trên Production.

**Yêu cầu tiên quyết:** Đã chốt kiến trúc trong `README.md`.

---

## Tổng quan các Phase

| Phase | Trọng tâm | Số Steps | Learning |
|---|---|---|---|
| **Phase 1-3** | Foundation, Docker, Compose, CI Skeleton | 14 | Local dev, Docker multi-stage |
| **Phase 4-5** | Core Domain & Outbox Pattern | 12 | Spring Boot, JPA, Outbox |
| **Phase 6-7** | Routing & Integrations | 10 | Kafka, REST Clients, Retry |
| **Phase 8-9** | Resilience & Observability | 10 | Circuit Breakers, OTel |
| **Phase 10-12** | Infrastructure (Terraform) & K8s (EKS) | 14 | IaC, VPC, EKS, Helm |
| **Phase 13-14** | CD Pipeline & Prod Readiness | 8 | GitHub Actions, SLOs, DR |

---

## Phase 1: Monorepo & Tooling Foundation
**Mục tiêu:** Thiết lập cấu trúc dự án đa module (Gradle/Maven), chuẩn hóa code style và CI skeleton cơ bản.

| # | Service/Component | File path | Mục tiêu | Verify commands | Depends on |
|---|---|---|---|---|---|
| ✅ 1.1 | Root | `build.gradle` (hoặc `pom.xml`) | Setup multi-module project (Spring Boot 3, Java 21) | `./gradlew build` | N/A |
| ✅ 1.2 | Root | `.editorconfig`, `checkstyle.xml` | Cấu hình code formatting chuẩn | `./gradlew check` | ✅ 1.1 |
| ✅ 1.3 | GitHub Actions | `.github/workflows/ci.yml` | Tạo CI skeleton (chạy lint/build trên PR) | Push PR -> check GHA green | 1.1, 1.2 |
| ✅ 1.4 | `shared-libs` | `shared-dto/src/main/java/` | Tạo các common models, enums (Currency, Status) | `./gradlew :shared-dto:build` | ✅ 1.1 |

## Phase 2: Dockerfiles Multi-stage
**Mục tiêu:** Đóng gói ứng dụng thành các Docker images tối ưu, bảo mật (non-root).

| # | Service/Component | File path | Mục tiêu | Verify commands | Depends on |
|---|---|---|---|---|---|
| ✅ 2.1 | `payment-api` | `payment-api/Dockerfile` | Viết multi-stage build cho payment-api (JDK builder -> JRE alpine) | `docker build -t payment-api:dev .` | ✅ 1.1 |
| ✅ 2.2 | `routing-engine` | `routing-engine/Dockerfile` | Viết multi-stage build cho routing-engine | `docker build -t routing:dev .` | ✅ 1.1 |
| ✅ 2.3 | `stripe-connector`| `stripe-connector/Dockerfile`| Viết multi-stage build cho stripe-connector | `docker build -t stripe:dev .` | ✅ 1.1 |
| ✅ 2.4 | All | `.dockerignore` | Loại bỏ `.git`, `.gradle`, `build/` khỏi context | Kiểm tra size image < 200MB | 2.1, 2.2, 2.3 |
| ✅ 2.5 | `payment-api` | `payment-api/Dockerfile` | Cấu hình non-root user (UID 1001) trong image | `docker run --rm payment-api:dev whoami` | ✅ 2.1 |

## Phase 3: Docker Compose (Local Stack)
**Mục tiêu:** Khởi chạy toàn bộ hạ tầng phụ thuộc (dependencies) trên máy local để dev không cần cài đặt rườm rà.

| # | Service/Component | File path | Mục tiêu | Verify commands | Depends on |
|---|---|---|---|---|---|
| ✅ 3.1 | Infra | `docker-compose.yml` | Thêm PostgreSQL (port 5432) + init script | `docker compose up -d postgres` | N/A |
| ✅ 3.2 | Infra | `docker-compose.yml` | Thêm Redis (port 6379) | `docker compose up -d redis` | N/A |
| ✅ 3.3 | Infra | `docker-compose.yml` | Thêm Zookeeper & Kafka (port 9092) | `docker exec -it kafka kafka-topics.sh --list` | N/A |
| ✅ 3.4 | Infra | `docker-compose.yml` | Thêm WireMock để giả lập Stripe API | `curl localhost:8081/__admin/mappings` | N/A |
| ✅ 3.5 | All | `docker-compose.yml` | Khai báo các app services build từ source | `docker compose up --build` | Phase 2, 3.1-3.4 |

## Phase 4: Core Domain (Payment API) & Database
**Mục tiêu:** Xây dựng API tạo thanh toán, xử lý lưu trữ vào PostgreSQL.

| # | Service/Component | File path | Mục tiêu | Verify commands | Depends on |
|---|---|---|---|---|---|
| ✅ 4.1 | `payment-api` | `src/main/resources/db/migration/`| Tạo Flyway scripts (Bảng `payments`, `outbox`) | App khởi động, DB schema tự tạo | ✅ 3.1 |
| ✅ 4.2 | `payment-api` | `PaymentEntity.java`, `Repo` | Mapping JPA entity cho Payment | Viết DataJpaTest (Testcontainers) | ✅ 4.1 |
| ✅ 4.3 | `payment-api` | `PaymentController.java` | Viết endpoint `POST /v1/payments` (nhận DTO, validate) | `curl -X POST ...` -> 200/202 | ✅ 4.2 |
| ✅ 4.4 | `payment-api` | `IdempotencyFilter.java` | Implement Idempotency dùng Redis `SETNX` | Gửi trùng key -> nhận cache hit | 3.2, 4.3 |

## Phase 5: Outbox Pattern & Event Publishing
**Mục tiêu:** Đảm bảo Transactional Messaging (không ghi DB thành công mà gửi Kafka thất bại và ngược lại).

| # | Service/Component | File path | Mục tiêu | Verify commands | Depends on |
|---|---|---|---|---|---|
| ✅ 5.1 | `payment-api` | `PaymentService.java` | Gom thao tác ghi `payments` và `outbox` vào 1 `@Transactional` | Inspect DB thấy cả 2 bảng có data | ✅ 4.3 |
| ✅ 5.2 | `payment-api` | `OutboxRelayScheduler.java` | (Phương án đơn giản) Polling bảng outbox định kỳ đẩy lên Kafka | `kafka-console-consumer.sh` nhận msg | 5.1, 3.3 |
| ✅ 5.3 | `payment-api` | `KafkaPublisher.java` | Viết logic publish msg vào topic `payment.created` | Log in producer success | ✅ 5.2 |
| ✅ 5.4 | `payment-api` | `OutboxRelayScheduler.java` | Đánh dấu event trong outbox đã publish (is_sent = true) | Inspect DB | ✅ 5.3 |

## Phase 6: Routing Engine
**Mục tiêu:** Đọc event từ Kafka và quyết định Gateway đích.

| # | Service/Component | File path | Mục tiêu | Verify commands | Depends on |
|---|---|---|---|---|---|
| ✅ 6.1 | `routing-engine` | `PaymentCreatedListener.java` | Consume message từ topic `payment.created` | Log thấy msg in ra ở routing app | ✅ 5.4 |
| ✅ 6.2 | `routing-engine` | `RoutingRuleService.java` | Logic (if-else/rules) chọn stripe hay paypal dựa trên loại thẻ | Unit tests (Mock) | N/A |
| ✅ 6.3 | `routing-engine` | `KafkaPublisher.java` | Publish quyết định vào topic `route.stripe` | Kiểm tra topic `route.stripe` | 6.1, 6.2 |

## Phase 7: External Integration (Stripe Connector)
**Mục tiêu:** Tương tác với hệ thống ngân hàng bên ngoài.

| # | Service/Component | File path | Mục tiêu | Verify commands | Depends on |
|---|---|---|---|---|---|
| ✅ 7.1 | `stripe-connector`| `RouteStripeListener.java` | Consume message từ `route.stripe` | Log consume success | ✅ 6.3 |
| ✅ 7.2 | `stripe-connector`| `StripeRestClient.java` | Gọi HTTP tới WireMock Stripe (Virtual Threads) | Wiremock log thấy request tới | 3.4, 7.1 |
| ✅ 7.3 | `stripe-connector`| `StripeRestClient.java` | Áp dụng Timeout, Retry logic (Spring Retry/Resilience4j) | Tắt wiremock -> thấy retry logs | ✅ 7.2 |
| ✅ 7.4 | `stripe-connector`| `KafkaPublisher.java` | Publish kết quả về topic `payment.result` | `kafka-console-consumer.sh` | ✅ 7.3 |
| ✅ 7.5 | `payment-api` | `PaymentResultListener.java`| Update status Payment trong PostgreSQL (PENDING -> SUCCESS) | E2E flow: POST payment -> DB is SUCCESS| 4.1, 7.4 |

## Phase 8: Resilience & Security
**Mục tiêu:** Hệ thống cứng cáp trước lỗi.

| # | Service/Component | File path | Mục tiêu | Verify commands | Depends on |
|---|---|---|---|---|---|
| 8.1 | `stripe-connector`| `CircuitBreakerConfig.java` | Bọc external call bằng Circuit Breaker | Ép Wiremock trả 500 liên tục -> ngắt CB | ✅ 7.3 |
| 8.2 | `payment-api` | `RateLimitingFilter.java` | Token Bucket rate limit dùng Redis theo IP/Merchant | Bắn > 10 req/s -> nhận 429 | 3.2, 4.3 |
| 8.3 | `payment-api` | `SecurityConfig.java` | JWT validation (Spring Security) cho endpoint API | Bắn API thiếu Token -> nhận 401 | ✅ 4.3 |

## Phase 9: Observability & Logging
**Mục tiêu:** Giám sát hệ thống.

| # | Service/Component | File path | Mục tiêu | Verify commands | Depends on |
|---|---|---|---|---|---|
| 9.1 | All | `application.yml` | Cấu hình Actuator expose Prometheus endpoints `/actuator/prometheus`| `curl .../actuator/prometheus` | Phase 4,6,7 |
| 9.2 | All | `pom.xml`/`build.gradle` | Thêm Micrometer Tracing (OTel), setup log format JSON | Log console ra JSON có TraceID | 9.1 |
| 9.3 | Infra | `docker-compose.yml` | Bổ sung Jaeger/Zipkin local để view traces | Mở UI Jaeger thấy E2E trace | 9.2 |

## Phase 10: Infrastructure as Code (Terraform)
**Mục tiêu:** Khởi tạo hạ tầng AWS.

| # | Service/Component | File path | Mục tiêu | Verify commands | Depends on |
|---|---|---|---|---|---|
| 10.1| Terraform | `infra/terraform/modules/vpc/` | Tạo VPC, Public/Private Subnets, NAT Gateway | `terraform plan` | N/A |
| 10.2| Terraform | `infra/terraform/modules/rds/` | Tạo RDS PostgreSQL Multi-AZ trong Private Subnet | `terraform plan` | 10.1 |
| 10.3| Terraform | `infra/terraform/modules/msk/` | Tạo MSK Cluster, Security Groups | `terraform plan` | 10.1 |
| 10.4| Terraform | `infra/terraform/modules/eks/` | Tạo EKS Cluster, Managed Node Groups | `terraform plan` | 10.1 |
| 10.5| Terraform | `infra/terraform/envs/staging/`| Gọi các modules để tạo staging env | `terraform apply` (trên lab) | 10.1-10.4 |

## Phase 11: EKS Setup & Base Manifests
**Mục tiêu:** Chuẩn bị môi trường Kubernetes.

| # | Service/Component | File path | Mục tiêu | Verify commands | Depends on |
|---|---|---|---|---|---|
| 11.1| K8s | N/A | Cài đặt Ingress Controller (AWS ALB Ingress) | `kubectl get pods -n kube-system` | 10.5 |
| 11.2| K8s | N/A | Cài đặt External Secrets Operator để đọc từ AWS SM | `kubectl get crds` | 11.1 |
| 11.3| `payment-api` | `deploy/helm/payment-api/` | Viết Helm chart (Deployment, Service, HPA) | `helm template` ra yaml chuẩn | 11.1 |
| 11.4| All | `deploy/helm/` | Hoàn thiện Helm charts cho `routing`, `stripe-connector`| `helm template` | 11.3 |

## Phase 12: Deployment (Staging)
**Mục tiêu:** Chạy hệ thống trên AWS Staging.

| # | Service/Component | File path | Mục tiêu | Verify commands | Depends on |
|---|---|---|---|---|---|
| 12.1| DB | N/A | Chạy DB Migration (Flyway) trên RDS staging (từ một jump host/CI) | Kết nối DB thấy bảng | 10.2, 4.1|
| 12.2| GitHub Actions | `.github/workflows/cd.yml` | Viết job build image -> Push lên ECR | Check ECR console | 1.3, 2.1 |
| 12.3| GitHub Actions | `.github/workflows/cd.yml` | Viết job run `helm upgrade --install` lên EKS Staging | `kubectl get pods -n staging` | 11.4, 12.2 |
| 12.4| Post-Deploy | N/A | Smoke test trên Staging ALB Endpoint | `curl <ALB_URL>/v1/payments` | 12.3 |

## Phase 13: CI/CD Prod Gate & Rollback
**Mục tiêu:** Quy trình deploy an toàn.

| # | Service/Component | File path | Mục tiêu | Verify commands | Depends on |
|---|---|---|---|---|---|
| 13.1| GitHub Actions | `.github/workflows/cd-prod.yml`| Thêm môi trường Prod, đòi hỏi Manual Approval | GHA dừng chờ approve | 12.3 |
| 13.2| K8s | N/A | Diễn tập Rollback: Update version lỗi, thực hiện `helm rollback` | App quay về version cũ ổn định | 12.3 |
| 13.3| K8s | N/A | Load test trên Staging (dùng K6 hoặc JMeter) kiểm tra HPA scale | `kubectl get hpa` thấy replicas tăng | 11.3 |

## Phase 14: Production Readiness
**Mục tiêu:** Sẵn sàng on-call và handover.

| # | Service/Component | File path | Mục tiêu | Verify commands | Depends on |
|---|---|---|---|---|---|
| 14.1| Docs | `docs/runbooks/db-failover.md` | Viết playbook xử lý khi RDS primary chết | Đọc hiểu | N/A |
| 14.2| K8s | `deploy/helm/...` | Cấu hình PodDisruptionBudgets (PDB) và Anti-Affinity | `kubectl get pdb` | 11.3 |
| 14.3| OTel | N/A | Dựng Dashboard Grafana (hoặc CloudWatch) đo SLOs | Mở Dashboard thấy Request Rate, Latency | 9.2, 12.4 |

---
**Learning Outcomes sau Roadmap:** Hoàn thành lộ trình này, bạn đã tự tay xây dựng một Core System với độ phức tạp cao, làm chủ việc tích hợp Java 21, Event-Driven, K8s và AWS. Cấu trúc monorepo giúp dễ theo dõi quá trình phát triển.
