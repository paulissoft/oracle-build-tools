package com.paulissoft.pato.jdbc;

import java.sql.SQLException;
import com.zaxxer.hikari.HikariDataSource;
import com.zaxxer.hikari.pool.HikariPool;
import org.springframework.beans.DirectFieldAccessor;
import lombok.extern.slf4j.Slf4j;


@Slf4j
public class SimplePoolDataSourceHikari extends HikariDataSource implements SimplePoolDataSource {

    public SimplePoolDataSourceHikari(final PoolDataSourceConfigurationHikari pdsConfigurationHikari) {
        super();
        log.info("SimplePoolDataSourceHikari(pdsConfigurationHikari={})", pdsConfigurationHikari);
        if (pdsConfigurationHikari.getDriverClassName() != null) {
            setDriverClassName(pdsConfigurationHikari.getDriverClassName());
        }
        setJdbcUrl(pdsConfigurationHikari.getUrl());
        setUsername(pdsConfigurationHikari.getUsername());
        setPassword(pdsConfigurationHikari.getPassword());
        setPoolName(pdsConfigurationHikari.getPoolName());
        setMaximumPoolSize(pdsConfigurationHikari.getMaximumPoolSize());
        setMinimumIdle(pdsConfigurationHikari.getMinimumIdle());
        setAutoCommit(pdsConfigurationHikari.isAutoCommit());
        setConnectionTimeout(pdsConfigurationHikari.getConnectionTimeout());
        setIdleTimeout(pdsConfigurationHikari.getIdleTimeout());
        setMaxLifetime(pdsConfigurationHikari.getMaxLifetime());
        setConnectionTestQuery(pdsConfigurationHikari.getConnectionTestQuery());
        setInitializationFailTimeout(pdsConfigurationHikari.getInitializationFailTimeout());
        setIsolateInternalQueries(pdsConfigurationHikari.isIsolateInternalQueries());
        setAllowPoolSuspension(pdsConfigurationHikari.isAllowPoolSuspension());
        setReadOnly(pdsConfigurationHikari.isReadOnly());
        setRegisterMbeans(pdsConfigurationHikari.isRegisterMbeans());
        setValidationTimeout(pdsConfigurationHikari.getValidationTimeout());
        setLeakDetectionThreshold(pdsConfigurationHikari.getLeakDetectionThreshold());
    }

    // get common pool data source properties like the ones define above
    public PoolDataSourceConfiguration getPoolDataSourceConfiguration() {
        return PoolDataSourceConfigurationHikari
            .builder()
            .driverClassName(getDriverClassName())
            .url(getJdbcUrl())
            .username(getUsername())
            .password(getPassword())
            .type(SimplePoolDataSourceHikari.class.getName())
            .poolName(getPoolName())
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

    public void updatePoolSizes(final SimplePoolDataSource pds) throws SQLException {
        log.debug(">updatePoolSizes()");

        final SimplePoolDataSourceHikari pdsHikari = (SimplePoolDataSourceHikari) pds;

        assert(this != pdsHikari);
        
        log.debug("pool sizes before: minimum/maximum: {}/{}/{}",
                     getMinimumIdle(),
                     getMaximumPoolSize());

        int oldSize, newSize;

        newSize = pdsHikari.getMinimumIdle();
        oldSize = getMinimumIdle();

        log.debug("minimum pool sizes before setting it: old/new: {}/{}",
                     oldSize,
                     newSize);

        if (newSize >= 0) {                
            setMinimumIdle(newSize + Integer.max(oldSize, 0));
        }
                
        newSize = pdsHikari.getMaximumPoolSize();
        oldSize = getMaximumPoolSize();

        log.debug("maximum pool sizes before setting it: old/new: {}/{}",
                     oldSize,
                     newSize);

        if (newSize >= 0) {
            setMaximumPoolSize(newSize + Integer.max(oldSize, 0));
        }
                
        log.debug("pool sizes after: minimum/maximum: {}/{}/{}",
                     getMinimumIdle(),
                     getMaximumPoolSize());
            
        log.debug("<updatePoolSizes()");
    }

    public String getUrl() {
        return getJdbcUrl();
    }
    
    public void setUrl(String url) {
        setJdbcUrl(url);
    }

    /*
    public void setConnectionFactoryClassName(String value) {
        try {
            if (DataSource.class.isAssignableFrom(Class.forName(value))) {
                setDataSourceClassName(value);
            } else if (Driver.class.isAssignableFrom(Class.forName(value))) {
                setDriverClassName(value);
            }
        } catch(ClassNotFoundException ex) {
            ; // ignore
        }
    }
    */

    // HikariCP does NOT know of an initial pool size
    public int getInitialPoolSize() {
        return -1;
    }

    public void setInitialPoolSize(int initialPoolSize) {
        ;
    }

    // HikariCP does NOT know of a minimum pool size but minimumIdle seems to be the equivalent
    public int getMinPoolSize() {
        return getMinimumIdle();
    }

    public void setMinPoolSize(int minPoolSize) {
        setMinimumIdle(minPoolSize);
    }        

    public int getMaxPoolSize() {
        return getMaximumPoolSize();
    }

    public void setMaxPoolSize(int maxPoolSize) {
        setMaximumPoolSize(maxPoolSize);
    }
    
    // https://stackoverflow.com/questions/40784965/how-to-get-the-number-of-active-connections-for-hikaricp
    private HikariPool getHikariPool() {
        return (HikariPool) new DirectFieldAccessor(this).getPropertyValue("pool");
    }

    public int getActiveConnections() {
        try {
            return getHikariPool().getActiveConnections();
        } catch (NullPointerException ex) {
            return -1;
        }
    }

    public int getIdleConnections() {
        try {
            return getHikariPool().getIdleConnections();
        } catch (NullPointerException ex) {
            return -1;
        }
    }

    public int getTotalConnections() {
        try {
            return getHikariPool().getTotalConnections();
        } catch (NullPointerException ex) {
            return -1;
        }
    }
}
