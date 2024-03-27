package com.paulissoft.pato.jdbc;

import java.io.Closeable;
import java.lang.reflect.Method;
import java.sql.Connection;
import java.sql.SQLException;
import java.sql.SQLFeatureNotSupportedException;
import java.util.Properties;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;
import javax.sql.DataSource;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NonNull;
import lombok.extern.slf4j.Slf4j;
import oracle.jdbc.OracleConnection;


@Slf4j
public abstract class CombiPoolDataSource<T extends DataSource> implements DataSource, Closeable {

    // We need to know the active parents in order to assign a value to an active parent so that a data source can use a common data source.
    // syntax error on: private static final ConcurrentHashMap<PoolDataSourceConfigurationCommonId, CombiPoolDataSource<T>> so use DataSource instead of T
    private static final ConcurrentHashMap<PoolDataSourceConfigurationCommonId, DataSource> activeParents = new ConcurrentHashMap<>();

    private final AtomicInteger activeChildren = new AtomicInteger(0);

    static void clear() {
        activeParents.clear();
    }    

    @NonNull
    private final T poolDataSource; // set in constructor

    private CombiPoolDataSource<T> activeParent = null;

    enum State {
        INITIALIZING,
        READY,
        CLOSING, // can not close due to children not closed yet
        ERROR,
        CLOSED
    }

    @NonNull
    private State state = State.INITIALIZING;

    @Getter
    private String usernameSession1;

    /**
     * Since getPassword() is a deprecated method (in Oracle UCP) we need another way of getting it.
     * The idea is to implement setPassword() here and store it in passwordSession1.
     * We need also to invoke poolDataSource.setPassword(password) via reflection.
     */

    @Getter(AccessLevel.PROTECTED)
    private String passwordSession1;

    @Getter
    private String usernameSession2;

    protected CombiPoolDataSource(@NonNull final T poolDataSource) {
        this.poolDataSource = poolDataSource;
        
        log.info("CombiCommonPoolDataSource({})", poolDataSource);
    }

    protected boolean isActive() {
        switch(state) {
        case READY:
            return true;
        default:
            return false;
        }
    }

    protected boolean isClosed() {
        switch(state) {
        case CLOSED:
            return true;
        default:
            return false;
        }
    }

    @jakarta.annotation.PostConstruct
    @javax.annotation.PostConstruct
    public final void open() {
        log.debug("open()");
        
        setUp();
    }

    // you can override this one
    protected void setUp() {
        log.debug("setUp(state={})", state);
        
        if (state == State.INITIALIZING) {
            determineConnectInfo();
            updateCombiPoolAdministration();
            updatePool(poolDataSource, determineCommonPoolDataSource(), true, activeParent == null);
            state = State.READY;
        }
    }

    public abstract PoolDataSourceConfiguration getPoolDataSourceConfiguration();

    private void updateCombiPoolAdministration() {
        log.debug("updateCombiPoolAdministration(state={})", state);
        
        final PoolDataSourceConfigurationCommonId commonId =
            new PoolDataSourceConfigurationCommonId(getPoolDataSourceConfiguration());
            
        if (state == State.INITIALIZING) {
            // Since the configuration is fixed now we can do lookups for an active parent.
            // The first pool data source (for same properties) will have activeParent == null
            activeParent = (CombiPoolDataSource<T>) activeParents.get(commonId); 

            if (activeParent != null && !activeParent.isActive()) {
                activeParent = null;
            }
            
            if (activeParent == null) {
                // The next with the same properties will get this one as activeParent
                activeParents.computeIfAbsent(commonId, k -> this);
            }
        }

        if (activeParent != null) {
            switch (state) {
            case INITIALIZING:
                activeParent.activeChildren.incrementAndGet();
                break;
            case READY:
                activeParent.activeChildren.decrementAndGet();
                break;
            default:
                break;
            }
        }
    }

    protected boolean canClose() {
        boolean result = false;
        
        switch(state) {
        case INITIALIZING:
            result = true;
            break;
        case READY:
        case CLOSING:
            result = activeParent == null || activeParent.activeChildren.get() == 0;
            break;
        case ERROR:
            result = true;
            break;
        case CLOSED:
            break;
        }

        log.debug("canClose() = {}", result);

        return result;
    }

    @jakarta.annotation.PreDestroy
    @javax.annotation.PreDestroy
    public final void close() {
        log.debug("close()");
        
        if (canClose()) {
            tearDown();
        }
    }

    // you may override this one
    protected void tearDown(){
        log.debug("tearDown(state={})", state);
        
        if (state != State.CLOSED) {
            updateCombiPoolAdministration();
            updatePool(poolDataSource, determineCommonPoolDataSource(), false, activeParent == null);
            state = State.CLOSED;
        }
    }

    protected void updatePoolName(@NonNull final T configPoolDataSource,
                                  @NonNull final T commonPoolDataSource,
                                  final boolean initializing,
                                  final boolean isParentPoolDataSource) {
    }

    protected void updatePoolSizes(@NonNull final T configPoolDataSource,
                                   @NonNull final T commonPoolDataSource,
                                   final boolean initializing) {

    }

    protected void updatePool(@NonNull final T configPoolDataSource,
                              @NonNull final T commonPoolDataSource,
                              final boolean initializing,
                              final boolean isParentPoolDataSource) {
        updatePoolName(configPoolDataSource,
                       commonPoolDataSource,
                       initializing,
                       isParentPoolDataSource);
        if (!isParentPoolDataSource) { // do not double the pool size when it is a activeParent
            updatePoolSizes(configPoolDataSource,
                            commonPoolDataSource,
                            initializing);
        }
    }

    protected void determineConnectInfo() {
        log.debug("determineConnectInfo()");
        
        final PoolDataSourceConfiguration configPoolDataSourceConfiguration = getPoolDataSourceConfiguration();

        configPoolDataSourceConfiguration.determineConnectInfo();
        usernameSession1 = configPoolDataSourceConfiguration.getUsernameToConnectTo();
        usernameSession2 = configPoolDataSourceConfiguration.getSchema();        
    }

    protected interface ToOverride {
        public Connection getConnection() throws SQLException;

        public Connection getConnection(String username, String password) throws SQLException;

        public void setUsername(String password) throws SQLException;

        public void setPassword(String password) throws SQLException;

        public String getPassword(); /* deprecated in oracle.ucp.jdbc.PoolDataSourceImpl */

        public void close();
    }

    // @Delegate(types=PoolDataSourcePropertiesSetters<T>.class, excludes=ToOverride.class)
    protected T determinePoolDataSourceSetter() {
        switch (state) {
        case INITIALIZING:
            return poolDataSource;
        case CLOSED:
            throw new IllegalStateException("You can not use the pool once it is closed().");
        default:
            throw new IllegalStateException("The configuration of the pool is sealed once started.");
        }
    }

    // @Delegate(types=PoolDataSourcePropertiesGetters<T>.class, excludes=ToOverride.class)
    protected T determinePoolDataSourceGetter() {
        switch (state) {
        case INITIALIZING:
            return poolDataSource;
        case CLOSED:
            throw new IllegalStateException("You can not use the pool once it is closed().");
        default:
            return activeParent != null ? activeParent.poolDataSource : poolDataSource;
        }
    }

    // @Delegate(types=<T>.class, excludes={ PoolDataSourcePropertiesSetters<T>.class, PoolDataSourcePropertiesGetters<T>.class, ToOverride.class })
    protected T determineCommonPoolDataSource() {
        switch (state) {
        case CLOSED:
            throw new IllegalStateException("You can not use the pool once it is closed().");
        default:
            return activeParent != null ? activeParent.poolDataSource : poolDataSource;
        }
    }

    protected boolean isSingleSessionProxyModel() {
        return PoolDataSourceConfiguration.SINGLE_SESSION_PROXY_MODEL;
    }

    protected boolean isFixedUsernamePassword() {
        return PoolDataSourceConfiguration.FIXED_USERNAME_PASSWORD;
    }
    
    public abstract String getUsername();

    public abstract void setUsername(String username) throws SQLException;

    public final String getPassword() {
        return passwordSession1;
    }

    public final void setPassword(String password) {
        passwordSession1 = password;

        try {
            final Method setPasswordMethod = poolDataSource.getClass().getMethod("setPassword", String.class);
            
            setPasswordMethod.invoke(poolDataSource, password);
        } catch (Exception ex) {
            throw new RuntimeException(SimplePoolDataSource.exceptionToString(ex));
        }
    }

    public final Connection getConnection() throws SQLException {
        switch (state) {
        case INITIALIZING:
            open();
            assert(state == State.READY);
            // fall through
        case READY:
        case CLOSING:
            break;
        default:
            throw new IllegalStateException(String.format("You can only get a connection when the pool state is READY or CLOSING but its state is %s.",
                                                          state.toString()));
        }
        
        final Connection conn = getConnection(usernameSession1,
                                              passwordSession1,
                                              usernameSession2);

        // check check double check
        assert conn.getSchema().equalsIgnoreCase(usernameSession2)
            : String.format("Current schema name (%s) should be the same as the requested name (%s)",
                            conn.getSchema(),
                            usernameSession2);

        return conn;
    }

    @Deprecated
    public final Connection getConnection(String username, String password) throws SQLException {
      throw new SQLFeatureNotSupportedException();

    }

    // two purposes:
    // 1) get a standard connection (session 1) but maybe with a different username/password than the default
    // 2) get a connection for the multi-session proxy model (session 2)
    protected Connection getConnection(@NonNull final String usernameSession1,
                                       @NonNull final String passwordSession1,
                                       @NonNull final String usernameSession2) throws SQLException {
        return getConnection2(getConnection1(usernameSession1, passwordSession1),
                              usernameSession1,
                              passwordSession1,
                              usernameSession2);
    }

    // get a standard connection (session 1) but maybe with a different username/password than the default
    protected abstract Connection getConnection1(@NonNull final String usernameSession1,
                                                 @NonNull final String passwordSession1) throws SQLException;

    // get a connection for the multi-session proxy model (session 2)
    protected Connection getConnection2(@NonNull final Connection conn,
                                        @NonNull final String usernameSession1,
                                        @NonNull final String passwordSession1,
                                        @NonNull final String usernameSession2) throws SQLException {
        log.debug("getConnection2(usernameSession1={}, usernameSession2={})",
                  usernameSession1,
                  usernameSession2);

        // if the current schema is not the requested schema try to open/close the proxy session
        if (!conn.getSchema().equalsIgnoreCase(usernameSession2)) {
            assert !isSingleSessionProxyModel()
                : "Requested schema name should be the same as the current schema name in the single-session proxy model";

            OracleConnection oraConn = null;

            try {
                if (conn.isWrapperFor(OracleConnection.class)) {
                    oraConn = conn.unwrap(OracleConnection.class);
                }
            } catch (SQLException ex) {
                oraConn = null;
            }

            if (oraConn != null) {
                int nr = 0;
                    
                do {
                    switch(nr) {
                    case 0:
                        if (oraConn.isProxySession()) {
                            // go back to the session with the first username
                            oraConn.close(OracleConnection.PROXY_SESSION);
                            oraConn.setSchema(usernameSession1);
                        }
                        break;
                            
                    case 1:
                        if (!usernameSession1.equals(usernameSession2)) {
                             // open a proxy session with the second username
                            final Properties proxyProperties = new Properties();

                            proxyProperties.setProperty(OracleConnection.PROXY_USER_NAME, usernameSession2);
                            oraConn.openProxySession(OracleConnection.PROXYTYPE_USER_NAME, proxyProperties);        
                            oraConn.setSchema(usernameSession2);
                        }
                        break;
                            
                    case 2:
                        oraConn.setSchema(usernameSession2);
                        break;
                            
                    default:
                        throw new IllegalArgumentException(String.format("Wrong value for nr (%d): must be between 0 and 2", nr));
                    }
                } while (!conn.getSchema().equalsIgnoreCase(usernameSession2) && nr++ < 3);
            }                
        }
        
        return conn;
    }
}
