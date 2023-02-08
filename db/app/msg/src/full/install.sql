REMARK Try to call Flyway script beforeEachMigrate.sql (add its directory to SQLPATH) so that PLSQL_CCFlags can be set.
REMARK But no harm done if it is not there.

whenever oserror continue
whenever sqlerror continue
@@beforeEachMigrate.sql

whenever oserror exit failure
whenever sqlerror exit failure
set define off sqlblanklines on
ALTER SESSION SET PLSQL_WARNINGS = 'ENABLE:ALL';

prompt @@02.TYPE_SPEC.MSG_TYP.sql
@@02.TYPE_SPEC.MSG_TYP.sql
show errors TYPE "MSG_TYP"
prompt @@02.TYPE_SPEC.REST_WEB_SERVICE_TYP.sql
@@02.TYPE_SPEC.REST_WEB_SERVICE_TYP.sql
show errors TYPE "REST_WEB_SERVICE_TYP"
prompt @@R__09.PACKAGE_SPEC.MSG_AQ_PKG.sql
@@R__09.PACKAGE_SPEC.MSG_AQ_PKG.sql
show errors PACKAGE "MSG_AQ_PKG"
prompt @@R__11.PROCEDURE.MSG_NOTIFICATION_PRC.sql
@@R__11.PROCEDURE.MSG_NOTIFICATION_PRC.sql
show errors PROCEDURE "MSG_NOTIFICATION_PRC"
prompt @@R__14.PACKAGE_BODY.MSG_AQ_PKG.sql
@@R__14.PACKAGE_BODY.MSG_AQ_PKG.sql
show errors PACKAGE BODY "MSG_AQ_PKG"
prompt @@R__15.TYPE_BODY.MSG_TYP.sql
@@R__15.TYPE_BODY.MSG_TYP.sql
show errors TYPE BODY "MSG_TYP"
prompt @@R__15.TYPE_BODY.REST_WEB_SERVICE_TYP.sql
@@R__15.TYPE_BODY.REST_WEB_SERVICE_TYP.sql
show errors TYPE BODY "REST_WEB_SERVICE_TYP"
