package com.omnipayx.payment.presentation.filter;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.Duration;
import java.util.Objects;

@Component
@Slf4j
@RequiredArgsConstructor
public class IdempotencyFilter extends OncePerRequestFilter {
    private final StringRedisTemplate redisTemplate;

    private static final String IDEMPOTENCY_HEADER = "Idempotency-Key";
    private static final String REDIS_PREFIX = "idemp:payment:";

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain) throws ServletException, IOException {
        if (!"POST".equalsIgnoreCase(request.getMethod())) {
            filterChain.doFilter(request, response);
            return;
        }

        String idempotencyKey = request.getHeader(IDEMPOTENCY_HEADER);

        if (idempotencyKey == null || idempotencyKey.isBlank()) {
            response.sendError(HttpStatus.BAD_REQUEST.value(), "Missing Idempotency-Key header");
            return;
        }

        Boolean isNewRequest = redisTemplate.opsForValue().setIfAbsent(REDIS_PREFIX + idempotencyKey, "PROCESSING", Duration.ofHours(24));

        if (Boolean.FALSE.equals(isNewRequest)) {
            log.warn("Duplicate request detected: {}", idempotencyKey);
            response.setStatus(HttpStatus.CONFLICT.value());
            response.setContentType("application/json");
            response.getWriter().write("{\"error\": \"Duplicate Request\"}");
            return;
        }

        filterChain.doFilter(request, response);
    }
}
