package com.omnipayx.payment.application;

import com.omnipayx.payment.domain.OutboxEntity;
import com.omnipayx.payment.infrastructure.OutboxRepository;
import com.omnipayx.payment.infrastructure.kafka.KafkaPublisher;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
@Slf4j
public class OutboxRelayScheduler {
    private final OutboxRepository outboxRepository;
    private final KafkaPublisher kafkaPublisher;
    private static final String TOPIC_PAYMENT_CREATED = "payment.created";

    @Scheduled(fixedDelay = 5000)
    @Transactional
    public void processOutboxEvents() {
        List<OutboxEntity> pendingEvents = outboxRepository.findByIsSentFalseOrderByCreatedAtAsc();
        if (pendingEvents.isEmpty()) return;

        log.info("Found {} pending outbox events to publish", pendingEvents.size());

        for (OutboxEntity event: pendingEvents) {
            try {
                kafkaPublisher.publish(TOPIC_PAYMENT_CREATED, event.getAggregateId(), event.getPayload());
                event.setSent(true);
                outboxRepository.save(event);
            } catch (Exception e) {
                log.error("Failed to publish outbox event id: {}", event.getId(), e);
            }
        }
    }
}
