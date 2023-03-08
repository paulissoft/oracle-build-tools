REMARK Try to call Flyway script beforeEachMigrate.sql (add its directory to SQLPATH) so that PLSQL_CCFlags can be set.
REMARK But no harm done if it is not there.

whenever oserror continue
whenever sqlerror continue
@@beforeEachMigrate.sql

whenever oserror exit failure
whenever sqlerror exit failure
set define off sqlblanklines on
ALTER SESSION SET PLSQL_WARNINGS = 'ENABLE:ALL';

prompt @@R__08.FUNCTION.DATA_SESSION_USERNAME.sql
@@R__08.FUNCTION.DATA_SESSION_USERNAME.sql
show errors FUNCTION "DATA_SESSION_USERNAME"
prompt @@R__08.FUNCTION.DATA_TIMESTAMP.sql
@@R__08.FUNCTION.DATA_TIMESTAMP.sql
show errors FUNCTION "DATA_TIMESTAMP"
prompt @@R__09.PACKAGE_SPEC.DATA_API_PKG.sql
@@R__09.PACKAGE_SPEC.DATA_API_PKG.sql
show errors PACKAGE "DATA_API_PKG"
prompt @@R__09.PACKAGE_SPEC.DATA_BR_PKG.sql
@@R__09.PACKAGE_SPEC.DATA_BR_PKG.sql
show errors PACKAGE "DATA_BR_PKG"
prompt @@R__09.PACKAGE_SPEC.DATA_PARTITIONING_PKG.sql
@@R__09.PACKAGE_SPEC.DATA_PARTITIONING_PKG.sql
show errors PACKAGE "DATA_PARTITIONING_PKG"
prompt @@R__09.PACKAGE_SPEC.DATA_TABLE_MGMT_PKG.sql
@@R__09.PACKAGE_SPEC.DATA_TABLE_MGMT_PKG.sql
show errors PACKAGE "DATA_TABLE_MGMT_PKG"
prompt @@R__14.PACKAGE_BODY.DATA_API_PKG.sql
@@R__14.PACKAGE_BODY.DATA_API_PKG.sql
show errors PACKAGE BODY "DATA_API_PKG"
prompt @@R__14.PACKAGE_BODY.DATA_BR_PKG.sql
@@R__14.PACKAGE_BODY.DATA_BR_PKG.sql
show errors PACKAGE BODY "DATA_BR_PKG"
prompt @@R__14.PACKAGE_BODY.DATA_PARTITIONING_PKG.sql
@@R__14.PACKAGE_BODY.DATA_PARTITIONING_PKG.sql
show errors PACKAGE BODY "DATA_PARTITIONING_PKG"
prompt @@R__14.PACKAGE_BODY.DATA_TABLE_MGMT_PKG.sql
@@R__14.PACKAGE_BODY.DATA_TABLE_MGMT_PKG.sql
show errors PACKAGE BODY "DATA_TABLE_MGMT_PKG"
prompt @@R__18.OBJECT_GRANT.DATA_SESSION_USERNAME.sql
@@R__18.OBJECT_GRANT.DATA_SESSION_USERNAME.sql
prompt @@R__18.OBJECT_GRANT.DATA_TIMESTAMP.sql
@@R__18.OBJECT_GRANT.DATA_TIMESTAMP.sql
prompt @@R__18.OBJECT_GRANT.DATA_API_PKG.sql
@@R__18.OBJECT_GRANT.DATA_API_PKG.sql
prompt @@R__18.OBJECT_GRANT.DATA_BR_PKG.sql
@@R__18.OBJECT_GRANT.DATA_BR_PKG.sql
prompt @@R__18.OBJECT_GRANT.DATA_PARTITIONING_PKG.sql
@@R__18.OBJECT_GRANT.DATA_PARTITIONING_PKG.sql
prompt @@R__18.OBJECT_GRANT.DATA_TABLE_MGMT_PKG.sql
@@R__18.OBJECT_GRANT.DATA_TABLE_MGMT_PKG.sql
