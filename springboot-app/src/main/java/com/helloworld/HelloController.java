package com.helloworld;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HelloController {

    @GetMapping("/")
    public String hello() {
        return "Hello World depuis Spring Boot ! (port 8080) - Deploye sur EKS";
    }

    @GetMapping("/health")
    public String health() {
        return "UP";
    }

    @GetMapping("/info")
    public String info() {
        return "Spring Boot 3.2.0 - AT2 Exam";
    }
}