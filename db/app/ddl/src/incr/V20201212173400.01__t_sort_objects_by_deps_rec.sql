/* To help Flyway */
BEGIN
  EXECUTE IMMEDIATE q'[
CREATE TYPE "ORACLE_TOOLS"."T_SORT_OBJECTS_BY_DEPS_REC" AS OBJECT (OBJECT_SCHEMA VARCHAR2(128 BYTE),
OBJECT_TYPE VARCHAR2(30 BYTE),
OBJECT_NAME VARCHAR2(128 BYTE),
DEPENDENCY_LIST VARCHAR2(4000 BYTE),
NR INTEGER)
]';
END;
/
