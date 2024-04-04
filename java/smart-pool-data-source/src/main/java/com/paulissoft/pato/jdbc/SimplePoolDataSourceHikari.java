package com.paulissoft.pato.jdbc;

import com.zaxxer.hikari.HikariDataSource;
import lombok.extern.slf4j.Slf4j;


@Slf4j
public class SimplePoolDataSourceHikari extends HikariDataSource implements SimplePoolDataSource {

    private final StringBuffer id = new StringBuffer();
         
    public void setId(final String srcId) {
        SimplePoolDataSource.setId(id, hashCode(), srcId);
    }

    public String getId() {
        return id.toString();
    }

    public void set(final PoolDataSourceConfiguration pdsConfig) {
        set((PoolDataSourceConfigurationHikari)pdsConfig);
    }
    
    private void set(final PoolDataSourceConfigurationHikari pdsConfig) {
        log.debug(">set(pdsConfig={})", pdsConfig);
        
        int nr = 0;
        final int maxNr = 18;
        
        do {
            try {
                switch(nr) {
                case  0: setDriverClassName(pdsConfig.getDriverClassName()); break;
                case  1: setJdbcUrl(pdsConfig.getUrl()); break;
                case  2: setUsername(pdsConfig.getUsername()); break;
                case  3: setPassword(pdsConfig.getPassword()); break;
                case  4: setPoolName(pdsConfig.getPoolName()); break;
                case  5: setMaximumPoolSize(pdsConfig.getMaximumPoolSize()); break;
                case  6: setMinimumIdle(pdsConfig.getMinimumIdle()); break;
                case  7: setAutoCommit(pdsConfig.isAutoCommit()); break;
                case  8: setConnectionTimeout(pdsConfig.getConnectionTimeout()); break;
                case  9: setIdleTimeout(pdsConfig.getIdleTimeout()); break;
                case 10: setMaxLifetime(pdsConfig.getMaxLifetime()); break;
                case 11: setConnectionTestQuery(pdsConfig.getConnectionTestQuery()); break;
                case 12: setInitializationFailTimeout(pdsConfig.getInitializationFailTimeout()); break;
                case 13: setIsolateInternalQueries(pdsConfig.isIsolateInternalQueries()); break;
                case 14: setAllowPoolSuspension(pdsConfig.isAllowPoolSuspension()); break;
                case 15: setReadOnly(pdsConfig.isReadOnly()); break;
                case 16: setRegisterMbeans(pdsConfig.isRegisterMbeans()); break;
                case 17: setValidationTimeout(pdsConfig.getValidationTimeout()); break;
                case 18: setLeakDetectionThreshold(pdsConfig.getLeakDetectionThreshold()); break;
                default:
                    throw new IllegalArgumentException(String.format("Wrong value for nr (%d): must be between 0 and %d", nr, maxNr));
                }
            } catch (Exception ex) {
                log.warn("nr: {}; exception: {}", nr, SimplePoolDataSource.exceptionToString(ex));
            }
        } while (++nr <= maxNr);

        log.debug("<set()");
    }

    public PoolDataSourceConfiguration get() {
        return get(true);
    }
    
    private PoolDataSourceConfiguration get(final boolean excludeNonIdConfiguration) {
        return PoolDataSourceConfigurationHikari
            .builder()
            .driverClassName(getDriverClassName())
            .url(getJdbcUrl())
            .username(getUsername())
            .password(excludeNonIdConfiguration ? null : getPassword())
            .type(SimplePoolDataSourceHikari.class.getName())
            .poolName(excludeNonIdConfiguration ? null : getPoolName())
            .maximumPoolSize(getMaximumPoolSize())
            .minimumIdle(getMinimumIdle())
            .autoCommit(isAutoCommit())
            .connectionTimeout(getConnectionTimeout())
            .idleTimeout(getIdleTimeout())
            .maxLifetime(getMaxLifetime())
            .connectionTestQuery(getConnectionTestQuery())
            .initializationFailTimeout(getInitializationFailTimeout())
            .isolateInternalQueries(isIsolateInternalQueries())
            .allowPoolSuspension(isAllowPoolSuspension())
            .readOnly(isReadOnly())
            .registerMbeans(isRegisterMbeans())
            .validationTimeout(getValidationTimeout())
            .leakDetectionThreshold(getLeakDetectionThreshold())
            .build();
    }
        
    public void show(final PoolDataSourceConfiguration pdsConfig) {
        show((PoolDataSourceConfigurationHikari)pdsConfig);
    }
    
    private void show(final PoolDataSourceConfigurationHikari pdsConfig) {
        final String indentPrefix = PoolDataSourceStatistics.INDENT_PREFIX;

        /* Smart Pool Data Source */
        
        log.info("Properties for smart pool connecting to schema {} via {}", pdsConfig.getSchema(), pdsConfig.getUsernameToConnectTo());

        /* info from PoolDataSourceConfiguration */
        log.info("{}url: {}", indentPrefix, pdsConfig.getUrl());
        log.info("{}username: {}", indentPrefix, pdsConfig.getUsername());
        // do not log passwords
        log.info("{}type: {}", indentPrefix, pdsConfig.getType());

        /* info from PoolDataSourceConfigurationHikari */
        log.info("{}maximumPoolSize: {}", indentPrefix, pdsConfig.getMaximumPoolSize());
        log.info("{}minimumIdle: {}", indentPrefix, pdsConfig.getMinimumIdle());
        log.info("{}dataSourceClassName: {}", indentPrefix, pdsConfig.getDataSourceClassName());
        log.info("{}autoCommit: {}", indentPrefix, pdsConfig.isAutoCommit());
        log.info("{}connectionTimeout: {}", indentPrefix, pdsConfig.getConnectionTimeout());
        log.info("{}idleTimeout: {}", indentPrefix, pdsConfig.getIdleTimeout());
        log.info("{}maxLifetime: {}", indentPrefix, pdsConfig.getMaxLifetime());
        log.info("{}connectionTestQuery: {}", indentPrefix, pdsConfig.getConnectionTestQuery());
        log.info("{}initializationFailTimeout: {}", indentPrefix, pdsConfig.getInitializationFailTimeout());
        log.info("{}isolateInternalQueries: {}", indentPrefix, pdsConfig.isIsolateInternalQueries());
        log.info("{}allowPoolSuspension: {}", indentPrefix, pdsConfig.isAllowPoolSuspension());
        log.info("{}readOnly: {}", indentPrefix, pdsConfig.isReadOnly());
        log.info("{}registerMbeans: {}", indentPrefix, pdsConfig.isRegisterMbeans());
        log.info("{}validationTimeout: {}", indentPrefix, pdsConfig.getValidationTimeout());
        log.info("{}leakDetectionThreshold: {}", indentPrefix, pdsConfig.getLeakDetectionThreshold());

        /* Common Simple Pool Data Source */
        
        log.info("Properties for common simple pool: {}", getPoolName());
        
        /* info from PoolDataSourceConfiguration */
        log.info("{}driverClassName: {}", indentPrefix, getDriverClassName());
        log.info("{}url: {}", indentPrefix, getJdbcUrl());
        log.info("{}username: {}", indentPrefix, getUsername());
        // do not log passwords
        /* info from PoolDataSourceConfigurationHikari */
        log.info("{}maximumPoolSize: {}", indentPrefix, getMaximumPoolSize());
        log.info("{}minimumIdle: {}", indentPrefix, getMinimumIdle());
        log.info("{}dataSourceClassName: {}", indentPrefix, getDataSourceClassName());
        log.info("{}autoCommit: {}", indentPrefix, isAutoCommit());
        log.info("{}connectionTimeout: {}", indentPrefix, getConnectionTimeout());
        log.info("{}idleTimeout: {}", indentPrefix, getIdleTimeout());
        log.info("{}maxLifetime: {}", indentPrefix, getMaxLifetime());
        log.info("{}connectionTestQuery: {}", indentPrefix, getConnectionTestQuery());
        log.info("{}initializationFailTimeout: {}", indentPrefix, getInitializationFailTimeout());
        log.info("{}isolateInternalQueries: {}", indentPrefix, isIsolateInternalQueries());
        log.info("{}allowPoolSuspension: {}", indentPrefix, isAllowPoolSuspension());
        log.info("{}readOnly: {}", indentPrefix, isReadOnly());
        log.info("{}registerMbeans: {}", indentPrefix, isRegisterMbeans());
        log.info("{}validationTimeout: {}", indentPrefix, getValidationTimeout());
        log.info("{}leakDetectionThreshold: {}", indentPrefix, getLeakDetectionThreshold());
        /*
        log.info("metricRegistry: {}", getMetricRegistry());
        log.info("healthCheckRegistry: {}", getHealthCheckRegistry());
        log.info("catalog: {}", getCatalog());
        log.info("connectionInitSql: {}", getConnectionInitSql());
        log.info("transactionIsolation: {}", getTransactionIsolation());
        log.info("dataSource: {}", getDataSource());
        log.info("schema: {}", getSchema());
        log.info("threadFactory: {}", getThreadFactory());
        log.info("scheduledExecutor: {}", getScheduledExecutor());
        */
    }

    // public void setPoolName(String poolName) throws SQLException;

    // public String getPoolName();
    
    // public void setUsername(String username) throws SQLException;

    // public String getUsername();

    // public void setPassword(String password) throws SQLException;

    // public String getPassword();
    
    // HikariCP does NOT know of an initial pool size so just return getMinPoolSize()
    public int getInitialPoolSize() {
        return getMinPoolSize();
    }

    // HikariCP does NOT know of a minimum pool size but minimumIdle seems to be the equivalent
    public int getMinPoolSize() {
        return getMinimumIdle();
    }

    public int getMaxPoolSize() {
        return getMaximumPoolSize();
    }

    // public long getConnectionTimeout(); // milliseconds

    public int getActiveConnections() {
        try {
            return getHikariPoolMXBean().getActiveConnections();
        } catch (NullPointerException ex) {
            return -1;
        }
    }

    public int getIdleConnections() {
        try {
            return getHikariPoolMXBean().getIdleConnections();
        } catch (NullPointerException ex) {
            return -1;
        }
    }

    public int getTotalConnections() {
        try {
            return getHikariPoolMXBean().getTotalConnections();
        } catch (NullPointerException ex) {
            return -1;
        }
    }

    /*
    @Override
    public boolean equals(Object obj) {
        if (obj == null || !(obj instanceof SimplePoolDataSourceHikari)) {
            return false;
        }

        final SimplePoolDataSourceHikari other = (SimplePoolDataSourceHikari) obj;
        
        return other.getPoolDataSourceConfiguration().equals(this.getPoolDataSourceConfiguration());
    }

    @Override
    public int hashCode() {
        return this.getPoolDataSourceConfiguration().hashCode();
    }

    @Override
    public String toString() {
        return this.getPoolDataSourceConfiguration().toString();
    }
    */
}
