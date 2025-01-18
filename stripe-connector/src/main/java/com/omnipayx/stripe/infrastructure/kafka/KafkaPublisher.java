package com.omnipayx.stripe.infrastructure.kafka;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
@Slf4j
public class KafkaPublisher {
    private final KafkaTemplate<String, String> kafkaTemplate;

    public void publishResult(String topic, String key, String status) {
        log.info("📤 Gửi kết quả thanh toán [{}] về topic [{}]", status, topic);
        kafkaTemplate.send(topic, key, "{\"status\": \"" + status + "\"}");
    }
}
