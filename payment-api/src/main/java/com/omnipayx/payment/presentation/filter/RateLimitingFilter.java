package com.omnipayx.payment.presentation.filter;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Collections;

@Component
@Slf4j
@RequiredArgsConstructor
public class RateLimitingFilter extends OncePerRequestFilter {

    private final StringRedisTemplate redisTemplate;
    private static final int MAX_REQUESTS_PER_MINUTE = 10; // Giới hạn 10 Req/Phút

    // Lua script đảm bảo tính Nguyên tử (Atomic) tuyệt đối
    private static final String LUA_SCRIPT =
        "local current = redis.call('get', KEYS[1]) " +
        "if current and tonumber(current) >= tonumber(ARGV[1]) then " +
        "    return 0 " + // Đã quá giới hạn -> Block
        "else " +
        "    local newValue = redis.call('incr', KEYS[1]) " +
        "    if newValue == 1 then " +
        "        redis.call('expire', KEYS[1], 60) " + // Gắn TTL 60 giây
        "    end " +
        "    return 1 " + // Cho phép đi tiếp
        "end";

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {

        String ip = request.getRemoteAddr();
        String redisKey = "rate_limit:ip:" + ip;

        // Khởi tạo script (Thực tế nên đưa ra ngoài làm Bean để tái sử dụng, nhưng ở đây dùng tạm cho gọn)
        DefaultRedisScript<Long> redisScript = new DefaultRedisScript<>(LUA_SCRIPT, Long.class);

        // Gọi Redis thực thi Lua Script
        Long result = redisTemplate.execute(
            redisScript,
            Collections.singletonList(redisKey),
            String.valueOf(MAX_REQUESTS_PER_MINUTE)
        );

        if (result == 0L) {
            log.warn("🚨 Lua Script: Rate limit exceeded for IP: {}", ip);
            response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value()); // Trả về mã 429
            response.getWriter().write("Too Many Requests");
            return;
        }

        filterChain.doFilter(request, response);
    }
}
