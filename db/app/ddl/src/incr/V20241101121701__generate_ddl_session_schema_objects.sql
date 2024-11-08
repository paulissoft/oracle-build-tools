create table generate_ddl_session_schema_objects
( session_id number default to_number(sys_context('USERENV', 'SESSIONID')) -- Primary key #1: The session id (v$session.audsid)
, schema_object_filter_id number -- Primary key #2
, seq integer constraint generate_ddl_session_schema_objects$ck$seq check (seq >= 1) -- Primary key #3: Sequence within (session_id, schema_object_filter_id)
, schema_object_id varchar2(500 byte) constraint generate_ddl_session_schema_objects$ck$schema_object_id check (schema_object_id is not null)
, created timestamp(6) default sys_extract_utc(systimestamp) constraint generate_ddl_session_schema_objects$ck$created check (created is not null)
, ddl oracle_tools.t_schema_ddl
, constraint generate_ddl_session_schema_objects$pk primary key (session_id, schema_object_filter_id, seq)
, constraint generate_ddl_session_schema_objects$uk$1 unique (session_id, schema_object_filter_id, schema_object_id)
, constraint generate_ddl_session_schema_objects$fk$1 foreign key (schema_object_filter_id, schema_object_id) references schema_object_filter_results(schema_object_filter_id, schema_object_id) on delete cascade
, constraint all_schema_ddls$ck$1 check (ddl is null or ddl.obj is null or ddl.obj.id = schema_object_id) -- only ddl for this schema object
)
nested table ddl.ddl_tab store as generate_ddl_session_schema_objects$ddl$ddl_tab
( nested table text store as generate_ddl_session_schema_objects$ddl$ddl_tab$text_tab )
;
