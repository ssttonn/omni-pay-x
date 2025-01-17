package com.omnipayx.payment.presentation.dto;

import com.omnipayx.dto.enums.PaymentStatus;
import lombok.Builder;
import lombok.Data;

import java.util.UUID;

@Data
@Builder
public class PaymentResponseDTO {
    private UUID paymentID;
    private PaymentStatus status;
}
