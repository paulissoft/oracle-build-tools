CREATE TABLE "ORACLE_TOOLS"."SCHEMA_OBJECT_FILTER_RESULTS" 
   (	"SCHEMA_OBJECT_FILTER_ID" NUMBER(*,0) CONSTRAINT "SCHEMA_OBJECT_FILTER_RESULTS$NNC$SCHEMA_OBJECT_FILTER_ID" NOT NULL ENABLE, 
	"SCHEMA_OBJECT_ID" VARCHAR2(500) CONSTRAINT "SCHEMA_OBJECT_FILTER_RESULTS$NNC$SCHEMA_OBJECT_ID" NOT NULL ENABLE, 
	"CREATED" TIMESTAMP (6) DEFAULT sys_extract_utc(systimestamp) CONSTRAINT "SCHEMA_OBJECT_FILTER_RESULTS$NNC$CREATED" NOT NULL ENABLE, 
	"GENERATE_DDL" NUMBER(1,0)
   )  DEFAULT COLLATION "USING_NLS_COMP"  
  PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 
 NOCOMPRESS LOGGING
  TABLESPACE "DATA";

