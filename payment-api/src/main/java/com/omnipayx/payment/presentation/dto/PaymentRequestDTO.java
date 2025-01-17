package com.omnipayx.payment.presentation.dto;

import com.omnipayx.dto.enums.Currency;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;

@Data
public class PaymentRequestDTO {
    @NotBlank
    private String merchantId;

    @NotNull
    @DecimalMin(value = "0.01")
    private BigDecimal amount;

    @NotNull
    private Currency currency;
}


