package com.omnipayx.stripe.infrastructure.client;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.retry.annotation.Backoff;
import org.springframework.retry.annotation.Retryable;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

@Component
@Slf4j
public class StripeRestClient {
    private final RestClient restClient;

    public StripeRestClient(@Value("${stripe.api.url}") String stripeUrl) {
        this.restClient = RestClient.builder()
            .baseUrl(stripeUrl)
            .build();
    }

    @Retryable(retryFor = Exception.class, maxAttempts = 3, backoff = @Backoff(delay = 2000))
    public boolean chargeCard(String paymentPayload) {
        log.info("💳 Đang gọi sang Stripe API giả lập...");
        try {
            String response = restClient.post()
                .uri("/v1/charges")
                .body(paymentPayload)
                .retrieve()
                .body(String.class);

            log.info("✅ Stripe API phản hồi thành công: {}", response);
            return true;
        } catch (Exception e) {
            log.error("❌ Gọi Stripe thất bại: {}", e.getMessage());
            return false;
        }
    }
}
