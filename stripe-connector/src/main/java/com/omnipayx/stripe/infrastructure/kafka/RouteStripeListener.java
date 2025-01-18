package com.omnipayx.stripe.infrastructure.kafka;

import com.omnipayx.stripe.infrastructure.client.StripeRestClient;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.KafkaHeaders;
import org.springframework.messaging.handler.annotation.Header;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
@Slf4j
public class RouteStripeListener {
    private final StripeRestClient stripeRestClient;
    private final KafkaPublisher kafkaPublisher;

    @KafkaListener(topics = "route-stripe", groupId = "stripe-connector-group")
    public void consumeRouteStripe(String payload, @Header(KafkaHeaders.RECEIVED_KEY) String aggregateId) {
        log.info("Nhận yêu cầu thanh toán Stripe ID: {}", aggregateId);

        try {
            boolean success = stripeRestClient.chargeCard(payload);
            String status = success ? "SUCCESS" : "FAILED";

            kafkaPublisher.publishResult("payment-result", aggregateId, status);
        } catch (Exception e) {
            // Lọt vào đây nghĩa là đã dùng hết 3 lần Retry mà vẫn xịt!
            log.error("Giao {} THẤT BẠI HOÀN TOÀN sau khi đã hết số lần Retry", aggregateId);
            kafkaPublisher.publishResult("payment-result", aggregateId, "FAILED");
        }
    }
}
