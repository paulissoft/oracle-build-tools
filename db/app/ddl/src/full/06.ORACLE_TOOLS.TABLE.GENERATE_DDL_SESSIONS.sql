CREATE TABLE "ORACLE_TOOLS"."GENERATE_DDL_SESSIONS" 
   (	"SESSION_ID" NUMBER DEFAULT to_number(sys_context('USERENV', 'SESSIONID')) CONSTRAINT "GENERATE_DDL_SESSIONS$NNC$SESSION_ID" NOT NULL ENABLE, 
	"GENERATE_DDL_CONFIGURATION_ID" NUMBER(*,0) CONSTRAINT "GENERATE_DDL_SESSIONS$NNC$GENERATE_DDL_CONFIGURATION_ID" NOT NULL ENABLE, 
	"SCHEMA_OBJECT_FILTER_ID" NUMBER(*,0) CONSTRAINT "GENERATE_DDL_SESSIONS$NNC$SCHEMA_OBJECT_FILTER_ID" NOT NULL ENABLE, 
	"CREATED" TIMESTAMP (6) DEFAULT sys_extract_utc(systimestamp) CONSTRAINT "GENERATE_DDL_SESSIONS$NNC$CREATED" NOT NULL ENABLE, 
	"USERNAME" VARCHAR2(128) CONSTRAINT "GENERATE_DDL_SESSIONS$NNC$USERNAME" NOT NULL ENABLE, 
	"UPDATED" TIMESTAMP (6)
   )  DEFAULT COLLATION "USING_NLS_COMP"  
  PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 
 NOCOMPRESS LOGGING
  TABLESPACE "DATA";

