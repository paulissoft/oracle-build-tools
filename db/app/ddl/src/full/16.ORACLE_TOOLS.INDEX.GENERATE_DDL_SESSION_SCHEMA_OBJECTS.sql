CREATE INDEX "ORACLE_TOOLS"."GENERATE_DDL_SESSION_SCHEMA_OBJECTS$FK$1" ON "ORACLE_TOOLS"."GENERATE_DDL_SESSION_SCHEMA_OBJECTS" ("SCHEMA_OBJECT_FILTER_ID", "SCHEMA_OBJECT_ID") 
  PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  TABLESPACE "USERS";

CREATE INDEX "ORACLE_TOOLS"."GENERATE_DDL_SESSION_SCHEMA_OBJECTS$FK$2" ON "ORACLE_TOOLS"."GENERATE_DDL_SESSION_SCHEMA_OBJECTS" ("SESSION_ID") 
  PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  TABLESPACE "USERS";

CREATE INDEX "ORACLE_TOOLS"."GENERATE_DDL_SESSION_SCHEMA_OBJECTS$FK$3" ON "ORACLE_TOOLS"."GENERATE_DDL_SESSION_SCHEMA_OBJECTS" ("SCHEMA_OBJECT_ID", "LAST_DDL_TIME", "GENERATE_DDL_CONFIGURATION_ID") 
  PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  TABLESPACE "USERS";

