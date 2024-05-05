package com.example.springboot;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.event.ContextRefreshedEvent;
import org.springframework.context.event.EventListener;
import org.springframework.core.env.ConfigurableEnvironment;
import org.springframework.core.env.MapPropertySource;
import org.springframework.stereotype.Component;

import java.util.Collection;

@Component
public class PropertiesPrinter {
    private static final Logger logger = LoggerFactory.getLogger(PropertiesPrinter.class);

    @EventListener
    public void handleContextRefreshed(ContextRefreshedEvent event) {
        printAllActiveProperties((ConfigurableEnvironment) event.getApplicationContext().getEnvironment());

        // printAllApplicationProperties((ConfigurableEnvironment) event.getApplicationContext().getEnvironment());
    }

    private void printAllActiveProperties(ConfigurableEnvironment env) {

        logger.info("************************* ALL PROPERTIES(EVENT) ******************************");

        env.getPropertySources()
            .stream()
            .filter(ps -> ps instanceof MapPropertySource)
            .map(ps -> ((MapPropertySource) ps).getSource().keySet())
            .flatMap(Collection::stream)
            .distinct()
            .sorted()
            .forEach(key -> logger.info("{}={}", key, env.getProperty(key)));

        logger.info("******************************************************************************");
    }

    private void printAllApplicationProperties(ConfigurableEnvironment env) {

        logger.info("************************* APP PROPERTIES(EVENT) ******************************");

        env.getPropertySources()
            .stream()
            .filter(ps -> ps instanceof MapPropertySource && ps.getName().contains("application.properties"))
            .map(ps -> ((MapPropertySource) ps).getSource().keySet())
            .flatMap(Collection::stream)
            .distinct()
            .sorted()
            .forEach(key -> logger.info("{}={}", key, env.getProperty(key)));

        logger.info("******************************************************************************");
    }
}
