package com.myapp.dailyjournal;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.boot.web.servlet.support.SpringBootServletInitializer;

/**
 * Entry point for the daily-journal application, runnable both as an
 * executable jar and as a WAR deployed to an external servlet container.
 */
@SpringBootApplication
public class DailyJournalApplication extends SpringBootServletInitializer {

    /**
     * Configures the application when deployed as a WAR under an
     * external servlet container.
     *
     * @param builder the builder to configure
     * @return the configured builder
     */
    @Override
    protected SpringApplicationBuilder configure(
            final SpringApplicationBuilder builder) {
        return builder.sources(DailyJournalApplication.class);
    }

    /**
     * Starts the application in standalone (embedded-server) mode.
     *
     * @param args command-line arguments, unused
     */
    public static void main(final String[] args) {
        SpringApplication.run(DailyJournalApplication.class, args);
    }
}
