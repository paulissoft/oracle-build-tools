REMARK Try to call Flyway script beforeEachMigrate.sql (add its directory to SQLPATH) so that PLSQL_CCFlags can be set.
REMARK But no harm done if it is not there.

whenever oserror continue
whenever sqlerror continue
@@beforeEachMigrate.sql

whenever oserror exit failure
whenever sqlerror exit failure
set define off sqlblanklines on
ALTER SESSION SET PLSQL_WARNINGS = 'ENABLE:ALL';

prompt @@R__09.PACKAGE_SPEC.API_CALL_STACK_PKG.sql
@@R__09.PACKAGE_SPEC.API_CALL_STACK_PKG.sql
show errors PACKAGE "API_CALL_STACK_PKG"
prompt @@R__09.PACKAGE_SPEC.API_LONGOPS_PKG.sql
@@R__09.PACKAGE_SPEC.API_LONGOPS_PKG.sql
show errors PACKAGE "API_LONGOPS_PKG"
prompt @@R__09.PACKAGE_SPEC.API_PKG.sql
@@R__09.PACKAGE_SPEC.API_PKG.sql
show errors PACKAGE "API_PKG"
prompt @@R__09.PACKAGE_SPEC.API_TIME_PKG.sql
@@R__09.PACKAGE_SPEC.API_TIME_PKG.sql
show errors PACKAGE "API_TIME_PKG"
prompt @@R__14.PACKAGE_BODY.API_CALL_STACK_PKG.sql
@@R__14.PACKAGE_BODY.API_CALL_STACK_PKG.sql
show errors PACKAGE BODY "API_CALL_STACK_PKG"
prompt @@R__14.PACKAGE_BODY.API_LONGOPS_PKG.sql
@@R__14.PACKAGE_BODY.API_LONGOPS_PKG.sql
show errors PACKAGE BODY "API_LONGOPS_PKG"
prompt @@R__14.PACKAGE_BODY.API_PKG.sql
@@R__14.PACKAGE_BODY.API_PKG.sql
show errors PACKAGE BODY "API_PKG"
prompt @@R__14.PACKAGE_BODY.API_TIME_PKG.sql
@@R__14.PACKAGE_BODY.API_TIME_PKG.sql
show errors PACKAGE BODY "API_TIME_PKG"
prompt @@R__18.OBJECT_GRANT.API_CALL_STACK_PKG.sql
@@R__18.OBJECT_GRANT.API_CALL_STACK_PKG.sql
prompt @@R__18.OBJECT_GRANT.API_LONGOPS_PKG.sql
@@R__18.OBJECT_GRANT.API_LONGOPS_PKG.sql
prompt @@R__18.OBJECT_GRANT.API_PKG.sql
@@R__18.OBJECT_GRANT.API_PKG.sql
prompt @@R__18.OBJECT_GRANT.API_TIME_PKG.sql
@@R__18.OBJECT_GRANT.API_TIME_PKG.sql
