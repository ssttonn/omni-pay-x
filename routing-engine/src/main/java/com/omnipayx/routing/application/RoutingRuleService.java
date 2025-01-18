package com.omnipayx.routing.application;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.SneakyThrows;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class RoutingRuleService {
    private final ObjectMapper objectMapper;

    @SneakyThrows
    public String determineGateway(String paymentPayload) {
        JsonNode payment = objectMapper.readTree(paymentPayload);
        String currency = payment.get("currency").asText();

        if ("EUR".equalsIgnoreCase(currency)) {
            return "route.paypal";
        }
        return "route-stripe";
    }
}
