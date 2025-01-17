package com.omnipayx.payment.presentation;

import com.omnipayx.payment.application.PaymentService;
import com.omnipayx.payment.domain.PaymentEntity;
import com.omnipayx.payment.presentation.dto.PaymentRequestDTO;
import com.omnipayx.payment.presentation.dto.PaymentResponseDTO;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/v1/payments")
@RequiredArgsConstructor
public class PaymentController {
    private final PaymentService paymentService;

    @PostMapping
    public ResponseEntity<PaymentResponseDTO> createPayment(
        @RequestHeader("Idempotency-Key") String idempotencyKey,
        @Valid @RequestBody PaymentRequestDTO request) {
        PaymentEntity entity = paymentService.createPayment(request, idempotencyKey);

        PaymentResponseDTO response = PaymentResponseDTO.builder()
            .paymentID(entity.getId())
            .status(entity.getStatus())
            .build();
        return ResponseEntity.status(HttpStatus.ACCEPTED).body(response);
    }
}
