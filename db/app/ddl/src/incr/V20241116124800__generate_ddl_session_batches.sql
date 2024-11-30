create table generate_ddl_session_batches
( session_id number
  constraint generate_ddl_session_batches$nnc$session_id not null -- Primary key #1
, seq integer
  constraint generate_ddl_session_batches$nnc$seq not null -- Primary key #2 (sequence within parent)
, created timestamp(6)
  default sys_extract_utc(systimestamp)
  constraint generate_ddl_session_batches$nnc$created not null
, schema varchar2(128 byte)
, transform_param_list varchar2(4000 byte) -- parameter from pkg_ddl_util.get_schema_ddl
-- select list from cursor c_params in body pkg_ddl_util
, object_schema varchar2(128 byte)
, object_type varchar2(30 byte)
, base_object_schema varchar2(128 byte)
, base_object_type varchar2(30 byte)
, object_name_tab oracle_tools.t_text_tab
, base_object_name_tab oracle_tools.t_text_tab
, nr_objects integer
, start_time timestamp(6)
, end_time timestamp(6)
, constraint generate_ddl_session_batches$pk
  primary key (session_id, seq)
, constraint generate_ddl_session_batches$fk$1
  foreign key (session_id)
  references generate_ddl_sessions(session_id) on delete cascade
)
nested table object_name_tab store as generate_ddl_session_batches$object_name_tab
nested table base_object_name_tab store as generate_ddl_session_batches$base_object_name_tab
;

alter table generate_ddl_session_batches nologging;

-- foreign key index generate_ddl_session_batches$fk$2 not necessary

COMMENT ON TABLE ORACLE_TOOLS.GENERATE_DDL_SESSION_BATCHES IS
    'DDL is generated in batches.';
