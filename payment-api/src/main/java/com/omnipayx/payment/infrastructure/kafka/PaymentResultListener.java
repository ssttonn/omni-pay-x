package com.omnipayx.payment.infrastructure.kafka;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.omnipayx.payment.application.PaymentService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.KafkaHeaders;
import org.springframework.messaging.handler.annotation.Header;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
@Slf4j
public class PaymentResultListener {
    private final PaymentService paymentService;
    private final ObjectMapper objectMapper;

    @KafkaListener(topics = "payment-result", groupId = "payment-api-group")
    public void consumePaymentResult(String payload, @Header(KafkaHeaders.RECEIVED_KEY) String aggregateId) {
        log.info("📥 Received payment result from Gateway for Payment ID: {}", aggregateId);

        try {
            JsonNode result = objectMapper.readTree(payload);
            String status = result.get("status").asText();
            paymentService.updatePaymentStatus(aggregateId, status);
        } catch (Exception e) {
            log.error("Error when parsing payment result: {}", e.getMessage());
        }
    }
}
