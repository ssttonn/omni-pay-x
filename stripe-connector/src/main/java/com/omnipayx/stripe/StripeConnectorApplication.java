package com.omnipayx.stripe;


import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.retry.annotation.EnableRetry;

@SpringBootApplication
@EnableRetry
public class StripeConnectorApplication {
    public static void main(String[] args) {
        SpringApplication.run(StripeConnectorApplication.class, args);
    }
}
