CREATE OR REPLACE PACKAGE BODY "ORACLE_TOOLS"."PKG_REPLICATE_UTIL" IS

procedure replicate_table
( p_table_name in varchar2 -- the table name
, p_table_owner in varchar2 -- the table owner
, p_column_list in varchar2 -- the columns separated by a comma
, p_create_or_replace in varchar2 default null -- or CREATE/REPLACE
, p_db_link in varchar2 default null -- database link: the table may reside on a separate database
  -- parameters below only relevant when database link is not null
, p_where_clause in varchar2 default null -- the where clause (without WHERE)
, p_read_only in boolean default true -- is the target read only?
)
is
  l_table_name all_tables.table_name%type;
  l_table_owner all_tables.owner%type;
  l_create_or_replace constant varchar(100) :=
    case
      when upper(p_create_or_replace) in ('CREATE', 'REPLACE')
      then upper(p_create_or_replace)
      else 'CREATE OR REPLACE'
    end;
  l_view_name all_tables.table_name%type;
begin

  case
    when p_db_link is null
    then
      l_table_name := oracle_tools.data_api_pkg.dbms_assert$enquote_name(p_table_name, 'table name');
      l_table_owner := oracle_tools.data_api_pkg.dbms_assert$enquote_name(p_table_owner, 'table owner');
      
      execute immediate l_create_or_replace || ' SYNONYM ' || l_table_name || ' FOR ' || l_table_owner || '.' || l_table_name;
  end case;
  
  l_view_name := oracle_tools.data_api_pkg.dbms_assert$enquote_name(p_table_name || '_V', 'view name');
  execute immediate l_create_or_replace || ' VIEW ' || l_view_name || ' AS SELECT ' || p_column_list || ' FROM ' || l_table_name;
end replicate_table;

end pkg_replicate_util;
/

