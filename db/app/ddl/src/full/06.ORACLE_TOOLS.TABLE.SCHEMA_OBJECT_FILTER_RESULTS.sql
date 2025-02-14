CREATE TABLE "ORACLE_TOOLS"."SCHEMA_OBJECT_FILTER_RESULTS" 
   (	"SCHEMA_OBJECT_FILTER_ID" NUMBER(*,0) CONSTRAINT "SCHEMA_OBJECT_FILTER_RESULTS$NNC$SCHEMA_OBJECT_FILTER_ID" NOT NULL ENABLE, 
	"SCHEMA_OBJECT_ID" VARCHAR2(500) CONSTRAINT "SCHEMA_OBJECT_FILTER_RESULTS$NNC$SCHEMA_OBJECT_ID" NOT NULL ENABLE, 
	"CREATED" TIMESTAMP (6) DEFAULT sys_extract_utc(systimestamp) CONSTRAINT "SCHEMA_OBJECT_FILTER_RESULTS$NNC$CREATED" NOT NULL ENABLE, 
	"GENERATE_DDL_DETAILS" VARCHAR2(1002) INVISIBLE CONSTRAINT "SCHEMA_OBJECT_FILTER_RESULTS$NNC$GENERATE_DDL_DETAILS" NOT NULL ENABLE, 
	"GENERATE_DDL" NUMBER(1,0) GENERATED ALWAYS AS (TO_NUMBER(LTRIM(SUBSTR("GENERATE_DDL_DETAILS",1,1)))) VIRTUAL , 
	"GENERATE_DDL_INFO" VARCHAR2(1000) GENERATED ALWAYS AS (SUBSTRB("GENERATE_DDL_DETAILS",3,1000)) VIRTUAL 
   )  
  PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 
 NOCOMPRESS NOLOGGING
  TABLESPACE "USERS";

