package com.omnipayx.payment.application;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.omnipayx.dto.enums.PaymentStatus;
import com.omnipayx.payment.domain.OutboxEntity;
import com.omnipayx.payment.domain.PaymentEntity;
import com.omnipayx.payment.infrastructure.OutboxRepository;
import com.omnipayx.payment.infrastructure.PaymentRepository;
import com.omnipayx.payment.presentation.dto.PaymentRequestDTO;
import lombok.RequiredArgsConstructor;
import lombok.SneakyThrows;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class PaymentService {
    private final PaymentRepository paymentRepository;
    private final OutboxRepository outboxRepository;
    private final ObjectMapper objectMapper;

    @Transactional
    @SneakyThrows
    public PaymentEntity createPayment(PaymentRequestDTO request, String idempotencyKey) {
        PaymentEntity payment = PaymentEntity.builder()
            .merchantId(request.getMerchantId())
            .amount(request.getAmount())
            .currency(request.getCurrency())
            .status(PaymentStatus.PENDING)
            .idempotencyKey(idempotencyKey)
            .build();

        PaymentEntity savedPayment = paymentRepository.save(payment);

        OutboxEntity outbox = OutboxEntity.builder()
            .aggregateType("PAYMENT")
            .aggregateId(savedPayment.getId().toString())
            .type("PAYMENT_CREATED")
            .payload(objectMapper.writeValueAsString(savedPayment))
            .build();

        outboxRepository.save(outbox);

        return savedPayment;
    }

    @Transactional
    public void updatePaymentStatus(String paymentIdStr, String statusStr) {
        try {
            UUID paymentId = UUID.fromString(paymentIdStr);
            PaymentStatus status = PaymentStatus.valueOf(statusStr);
            PaymentEntity payment = paymentRepository.findById(paymentId).orElseThrow(() -> new IllegalArgumentException("Payment not existed"));

            payment.setStatus(status);

            paymentRepository.save(payment);

            log.info("✅ Payment [{}] status update successfully, new status: [{}]!", paymentId, status);
        } catch (Exception e) {
            log.error("Failed to update payment: {}", e.getMessage());
        }
    }
}
