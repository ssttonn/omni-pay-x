package com.omnipayx.routing.infrastructure.kafka;

import com.omnipayx.routing.application.RoutingRuleService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.KafkaHeaders;
import org.springframework.messaging.handler.annotation.Header;
import org.springframework.stereotype.Component;

@Component
@Slf4j
@RequiredArgsConstructor
public class PaymentCreatedListener {
    private final RoutingRuleService routingRuleService;
    private final KafkaPublisher kafkaPublisher;

    @KafkaListener(topics = "payment.created", groupId = "routing-engine-group")
    public void consumePaymentCreated(String payload, @Header(KafkaHeaders.RECEIVED_KEY) String aggregateId) {
        log.info("🔔 BING BONG! Receive new payment from Kafka: {}", payload);

        String targetTopic = routingRuleService.determineGateway(payload);

        kafkaPublisher.publish(targetTopic, aggregateId, payload);
    }
}
