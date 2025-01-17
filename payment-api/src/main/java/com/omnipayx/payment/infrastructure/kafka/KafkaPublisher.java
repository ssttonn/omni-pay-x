package com.omnipayx.payment.infrastructure.kafka;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
@Slf4j
public class KafkaPublisher {

    private final KafkaTemplate<String, String> kafkaTemplate;

    public void publish(String topic, String key, String payload) {
        log.info("Publishing event to Kafka | Topic: {} | Key {}", topic, key);
        kafkaTemplate.send(topic, key, payload);
    }
}
