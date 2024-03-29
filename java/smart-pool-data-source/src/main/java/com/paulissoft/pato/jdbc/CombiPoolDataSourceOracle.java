package com.paulissoft.pato.jdbc;

import java.sql.Connection;
import java.sql.SQLException;
import lombok.NonNull;
import lombok.experimental.Delegate;
import lombok.extern.slf4j.Slf4j;
import oracle.ucp.jdbc.PoolDataSource;
import oracle.ucp.jdbc.PoolDataSourceImpl;


@Slf4j
public class CombiPoolDataSourceOracle extends CombiPoolDataSource<PoolDataSource> implements PoolDataSource, PoolDataSourcePropertiesSettersOracle, PoolDataSourcePropertiesGettersOracle {

    private static final String POOL_NAME_PREFIX = "OraclePool";

    public CombiPoolDataSourceOracle() {
        this(new PoolDataSourceImpl());
        log.info("CombiPoolDataSourceOracle()");
    }

    private CombiPoolDataSourceOracle(@NonNull final PoolDataSource configPoolDataSource) {
        super(configPoolDataSource);
        log.info("CombiPoolDataSourceOracle({})", configPoolDataSource);
    }

    // setXXX methods only (determinePoolDataSourceSetter() may return different values depending on state hence use a function)
    @Delegate(types=PoolDataSourcePropertiesSettersOracle.class, excludes=ToOverride.class) // do not delegate setPassword()
    private PoolDataSource getPoolDataSourceSetter() {
        return determinePoolDataSourceSetter();
    }

    // getXXX methods only (determinePoolDataSourceGetter() may return different values depending on state hence use a function)
    @Delegate(types=PoolDataSourcePropertiesGettersOracle.class, excludes=ToOverride.class)
    private PoolDataSource getPoolDataSourceGetter() {
        return determinePoolDataSourceGetter();
    }
    
    // no getXXX() nor setXXX(), just the rest (determineCommonPoolDataSource() may return different values depending on state hence use a function)
    @Delegate(excludes={ PoolDataSourcePropertiesOracle.class, ToOverride.class })
    private PoolDataSource getCommonPoolDataSource() {
        return determineCommonPoolDataSource();
    }

    public String getUrl() {
        return getURL();
    }
  
    public void setUrl(String jdbcUrl) throws SQLException {
        setURL(jdbcUrl);
    }
  
    public String getUsername() {
        return getUser();
    }

    public void setUsername(String username) throws SQLException {
        setUser(username);        
    }

    public PoolDataSourceConfiguration getPoolDataSourceConfiguration() {
        return getPoolDataSourceConfiguration(true);
    }
    
    private PoolDataSourceConfiguration getPoolDataSourceConfiguration(final boolean excludeNonIdConfiguration) {
        return PoolDataSourceConfigurationOracle
            .builder()
            .driverClassName(null)
            .url(getURL())
            .username(getUser())
            .password(excludeNonIdConfiguration ? null : getPassword())
            .type(SimplePoolDataSourceOracle.class.getName())
            .connectionPoolName(excludeNonIdConfiguration ? null : getConnectionPoolName())
            .initialPoolSize(getInitialPoolSize())
            .minPoolSize(getMinPoolSize())
            .maxPoolSize(getMaxPoolSize())
            .connectionFactoryClassName(getConnectionFactoryClassName())
            .validateConnectionOnBorrow(getValidateConnectionOnBorrow())
            .abandonedConnectionTimeout(getAbandonedConnectionTimeout())
            .timeToLiveConnectionTimeout(getTimeToLiveConnectionTimeout())
            .inactiveConnectionTimeout(getInactiveConnectionTimeout())
            .timeoutCheckInterval(getTimeoutCheckInterval())
            .maxStatements(getMaxStatements())
            .connectionWaitTimeout(getConnectionWaitTimeout())
            .maxConnectionReuseTime(getMaxConnectionReuseTime())
            .secondsToTrustIdleConnection(getSecondsToTrustIdleConnection())
            .connectionValidationTimeout(getConnectionValidationTimeout())
            .build();
    }

    protected Connection getConnection1(@NonNull final PoolDataSource commonPoolDataSource,
                                        @NonNull final String usernameSession1,
                                        @NonNull final String passwordSession1) throws SQLException {
        log.debug("getConnection1(usernameSession1={})", usernameSession1);

        return commonPoolDataSource.getConnection(usernameSession1, passwordSession1);
    }
    
    protected Connection getConnection(@NonNull final PoolDataSource commonPoolDataSource,
                                       @NonNull final String usernameSession1,
                                       @NonNull final String passwordSession1,
                                       @NonNull final String usernameSession2) throws SQLException {
        // we do use single-session proxy model so no need to invoke getConnection2()
        return getConnection1(commonPoolDataSource, usernameSession1, passwordSession1);
    }

    protected void updatePool(@NonNull final PoolDataSource configPoolDataSource,
                              @NonNull final PoolDataSource commonPoolDataSource,
                              final boolean initializing,
                              final boolean isParentPoolDataSource) {
        try {
            log.debug(">updatePoolName(isParentPoolDataSource={})", isParentPoolDataSource);
            
            log.debug("config pool data source; address: {}; name: {}",
                      configPoolDataSource,
                      configPoolDataSource.getConnectionPoolName());

            log.debug("common pool data source; address: {}; name: {}",
                      commonPoolDataSource,
                      commonPoolDataSource.getConnectionPoolName());

            // set pool name
            if (initializing && isParentPoolDataSource) {
                commonPoolDataSource.setConnectionPoolName(POOL_NAME_PREFIX);
            }

            final String suffix = "-" + getUsernameSession2();

            if (initializing) {
                commonPoolDataSource.setConnectionPoolName(commonPoolDataSource.getConnectionPoolName() + suffix);
            } else {
                commonPoolDataSource.setConnectionPoolName(commonPoolDataSource.getConnectionPoolName().replace(suffix, ""));
            }
        } catch (SQLException ex) {
            throw new RuntimeException(SimplePoolDataSource.exceptionToString(ex));
        } finally {
            log.debug("config pool data source; address: {}; name: {}",
                      configPoolDataSource,
                      configPoolDataSource.getConnectionPoolName());

            log.debug("common pool data source; address: {}; name: {}",
                      commonPoolDataSource,
                      commonPoolDataSource.getConnectionPoolName());

            log.debug("<updatePoolName()");
        }
    }

    protected void updatePoolSizes(@NonNull final PoolDataSource configPoolDataSource,
                                   @NonNull final PoolDataSource commonPoolDataSource,
                                   final boolean initializing) {
        try {
            log.debug(">updatePoolSizes()");
            
            log.debug("config pool data source; address: {}; name: {}; pool sizes before: initial/minimum/maximum: {}/{}/{}",
                      configPoolDataSource,
                      configPoolDataSource.getConnectionPoolName(),
                      configPoolDataSource.getInitialPoolSize(),
                      configPoolDataSource.getMinPoolSize(),
                      configPoolDataSource.getMaxPoolSize());

            log.debug("common pool data source; address: {}; name: {}; pool sizes before: initial/minimum/maximum: {}/{}/{}",
                      commonPoolDataSource,
                      commonPoolDataSource.getConnectionPoolName(),
                      commonPoolDataSource.getInitialPoolSize(),
                      commonPoolDataSource.getMinPoolSize(),
                      commonPoolDataSource.getMaxPoolSize());
            
            // when configPoolDataSource equals commonPoolDataSource there is no need to adjust pool sizes
            final int sign = initializing ? +1 : -1;

            int thisSize, pdsSize;

            pdsSize = configPoolDataSource.getInitialPoolSize();
            thisSize = Integer.max(commonPoolDataSource.getInitialPoolSize(), 0);

            log.debug("initial pool sizes before changing it: this/pds: {}/{}",
                      thisSize,
                      pdsSize);

            if (pdsSize >= 0 && sign * pdsSize <= Integer.MAX_VALUE - thisSize) {
                commonPoolDataSource.setInitialPoolSize(pdsSize + thisSize);
            }

            pdsSize = configPoolDataSource.getMinPoolSize();
            thisSize = Integer.max(commonPoolDataSource.getMinPoolSize(), 0);

            log.debug("minimum pool sizes before changing it: this/pds: {}/{}",
                      thisSize,
                      pdsSize);

            if (pdsSize >= 0 && sign * pdsSize <= Integer.MAX_VALUE - thisSize) {                
                commonPoolDataSource.setMinPoolSize(pdsSize + thisSize);
            }
                
            pdsSize = configPoolDataSource.getMaxPoolSize();
            thisSize = Integer.max(commonPoolDataSource.getMaxPoolSize(), 0);

            log.debug("maximum pool sizes before changing it: this/pds: {}/{}",
                      thisSize,
                      pdsSize);

            if (pdsSize >= 0 && sign * pdsSize <= Integer.MAX_VALUE - thisSize) {
                commonPoolDataSource.setMaxPoolSize(pdsSize + thisSize);
            }
        } catch (SQLException ex) {
            throw new RuntimeException(SimplePoolDataSource.exceptionToString(ex));
        } finally {
            log.debug("config pool data source; address: {}; name: {}; pool sizes after: initial/minimum/maximum: {}/{}/{}",
                      configPoolDataSource,
                      configPoolDataSource.getConnectionPoolName(),
                      configPoolDataSource.getInitialPoolSize(),
                      configPoolDataSource.getMinPoolSize(),
                      configPoolDataSource.getMaxPoolSize());

            log.debug("common pool data source; address: {}; name: {}; pool sizes after: initial/minimum/maximum: {}/{}/{}",
                      commonPoolDataSource,
                      commonPoolDataSource.getConnectionPoolName(),
                      commonPoolDataSource.getInitialPoolSize(),
                      commonPoolDataSource.getMinPoolSize(),
                      commonPoolDataSource.getMaxPoolSize());

            log.debug("<updatePool()");
        }
    }
}
