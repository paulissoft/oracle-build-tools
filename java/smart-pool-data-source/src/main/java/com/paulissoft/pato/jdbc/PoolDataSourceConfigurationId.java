package com.paulissoft.pato.jdbc;


class PoolDataSourceConfigurationId {

    private String id;

    PoolDataSourceConfigurationId(final PoolDataSourceConfiguration poolDataSourceConfiguration) {
        final PoolDataSourceConfiguration copy = poolDataSourceConfiguration.toBuilder().build(); // a copy

        copy.clearNonIdConfiguration();
        
        this.id = copy.toString();
    }
    
    @Override
    public boolean equals(Object obj) {
        if (obj == null || !(obj instanceof PoolDataSourceConfigurationId)) {
            return false;
        }

        PoolDataSourceConfigurationId other = (PoolDataSourceConfigurationId) obj;
        
        return other.id.equals(this.id);
    }

    @Override
    public int hashCode() {
        return this.id.hashCode();
    }

    @Override
    public String toString() {
        return id;
    }
}
