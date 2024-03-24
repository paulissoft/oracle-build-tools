package com.paulissoft.pato.jdbc;

import com.zaxxer.hikari.HikariDataSource;
import com.zaxxer.hikari.HikariConfigMXBean;
import jakarta.annotation.PostConstruct;
//import jakarta.annotation.PreDestroy;
import java.sql.Connection;
import java.sql.SQLException;
import lombok.NonNull;
import lombok.experimental.Delegate;
import lombok.extern.slf4j.Slf4j;


@Slf4j
public class CombiPoolDataSourceHikari extends CombiPoolDataSource<HikariDataSource> implements HikariConfigMXBean, PoolDataSourcePropertiesHikari {

    @Delegate(types=PoolDataSourcePropertiesHikari.class, excludes=ToOverride.class) // do not delegate setPassword()
    private HikariDataSource configPoolDataSource = null;

    @Delegate(excludes=ToOverride.class)
    private HikariDataSource commonPoolDataSource = null;

    public CombiPoolDataSourceHikari() {
        this(new HikariDataSource());
    }

    private CombiPoolDataSourceHikari(@NonNull final HikariDataSource configPoolDataSource) {
        super(configPoolDataSource, null);
    }
    
    private CombiPoolDataSourceHikari(@NonNull final HikariDataSource configPoolDataSource, final CombiPoolDataSourceHikari commonCombiPoolDataSource) {
        super(configPoolDataSource, commonCombiPoolDataSource);
    }
        
    protected boolean isSingleSessionProxyModel() {
        return PoolDataSourceConfiguration.SINGLE_SESSION_PROXY_MODEL;
    }

    protected boolean isFixedUsernamePassword() {
        return PoolDataSourceConfiguration.FIXED_USERNAME_PASSWORD;
    }

    @Override
    public void setPassword(String password) {
        try {
            super.setPassword(password);
            getConfigPoolDataSource().setPassword(password);
        } catch (SQLException ex) {
            throw new RuntimeException(SimplePoolDataSource.exceptionToString(ex));
        }
    }

    public PoolDataSourceConfiguration getPoolDataSourceConfiguration() {
        return getPoolDataSourceConfiguration(true);
    }
    
    public PoolDataSourceConfiguration getPoolDataSourceConfiguration(final boolean excludeNonIdConfiguration) {
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

    // only setters and getters
    @Override
    protected HikariDataSource getConfigPoolDataSource() {
        return super.getConfigPoolDataSource();
    }

    @PostConstruct
    @Override
    public void init() {
        super.init();
        configPoolDataSource = getConfigPoolDataSource();
        commonPoolDataSource = getCommonPoolDataSource();
    }

    public Connection getConnection() throws SQLException {
        return getConnection(getUsernameSession1(), getPasswordSession1(), getUsernameSession2());
    }

    public Connection getConnection(String username, String password) throws SQLException {
        return getCommonPoolDataSource().getConnection(username, password);
    }

    protected void updatePool(@NonNull final HikariDataSource configPoolDataSource,
                              @NonNull final HikariDataSource commonPoolDataSource,
                              final boolean initializing) {
        if (configPoolDataSource == commonPoolDataSource) {
            return;
        }
        
        final int sign = initializing ? +1 : -1;

        try {
            log.debug("pool sizes before: minimum/maximum: {}/{}/{}",
                      commonPoolDataSource.getMinimumIdle(),
                      commonPoolDataSource.getMaximumPoolSize());

            int thisSize, pdsSize;

            pdsSize = configPoolDataSource.getMinimumIdle();
            thisSize = Integer.max(commonPoolDataSource.getMinimumIdle(), 0);

            log.debug("minimum pool sizes before changing it: this/pds: {}/{}",
                      thisSize,
                      pdsSize);

            if (pdsSize >= 0 && sign * pdsSize <= Integer.MAX_VALUE - thisSize) {                
                commonPoolDataSource.setMinimumIdle(pdsSize + thisSize);
            }
                
            pdsSize = configPoolDataSource.getMaximumPoolSize();
            thisSize = Integer.max(commonPoolDataSource.getMaximumPoolSize(), 0);

            log.debug("maximum pool sizes before changing it: this/pds: {}/{}",
                      thisSize,
                      pdsSize);

            if (pdsSize >= 0 && sign * pdsSize <= Integer.MAX_VALUE - thisSize) {
                commonPoolDataSource.setMaximumPoolSize(pdsSize + thisSize);
            }

            commonPoolDataSource.setPoolName(commonPoolDataSource.getPoolName() + "-" + getUsernameSession2());
        } finally {
            log.debug("pool sizes after: minimum/maximum: {}/{}/{}",
                      commonPoolDataSource.getMinimumIdle(),
                      commonPoolDataSource.getMaximumPoolSize());

            log.debug("<update()");
        }
    }

    @Override
    public void close() {
        if (canClose()) {
            commonPoolDataSource.close();
        }
    }
}
