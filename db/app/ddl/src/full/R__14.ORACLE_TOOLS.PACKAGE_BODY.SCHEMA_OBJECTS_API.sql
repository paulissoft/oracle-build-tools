CREATE OR REPLACE PACKAGE BODY "ORACLE_TOOLS"."SCHEMA_OBJECTS_API" IS /* -*-coding: utf-8-*- */

-- PRIVATE
/*
subtype t_object is oracle_tools.pkg_ddl_util.t_object;
subtype t_object_names is oracle_tools.pkg_ddl_util.t_object_names;
subtype t_schema is oracle_tools.pkg_ddl_util.t_schema;
*/
subtype t_module is varchar2(100);
subtype t_numeric_boolean is oracle_tools.pkg_ddl_util.t_numeric_boolean;
subtype t_schema_nn is oracle_tools.pkg_ddl_util.t_schema_nn;

-- steps in get_schema_objects
"named objects" constant varchar2(30 char) := 'base objects';
"object grants" constant varchar2(30 char) := 'object grants';
"synonyms" constant varchar2(30 char) := 'synonyms';
"comments" constant varchar2(30 char) := 'comments';
"constraints" constant varchar2(30 char) := 'constraints';
"triggers" constant varchar2(30 char) := 'triggers';
"indexes" constant varchar2(30 char) := 'indexes';

c_steps constant sys.odcivarchar2list :=
  sys.odcivarchar2list
  ( "named objects"                 -- no base object
  , "object grants"                 -- base object (named)
  , "synonyms"                      -- base object (named)
  , "comments"                      -- base object (named)
  , "constraints"                   -- base object (named)
  , "triggers"                      -- base object (NOT named)
  , "indexes"                       -- base object (NOT named)
  );

g_default_match_perc_threshold integer := 50;

g_session_id t_session_id := to_number(sys_context('USERENV', 'SESSIONID'));

function get_schema_object_filter_id
( p_session_id in t_session_id
)
return positive
is
  l_schema_object_filter_id positive;
begin
  select  gds.schema_object_filter_id
  into    l_schema_object_filter_id
  from    generate_ddl_sessions gds
  where   gds.session_id = p_session_id;
  return l_schema_object_filter_id;
exception
  when no_data_found
  then return null;
end get_schema_object_filter_id;

procedure get_named_objects
( p_schema in varchar2
, p_schema_object_tab out nocopy oracle_tools.t_schema_object_tab
)
is
  type t_excluded_tables_tab is table of boolean index by all_tables.table_name%type;

  l_excluded_tables_tab t_excluded_tables_tab;

  l_schema_md_object_type_tab constant pkg_ddl_util.t_md_object_type_tab :=
    oracle_tools.pkg_ddl_util.get_md_object_type_tab('SCHEMA');
begin
$if oracle_tools.schema_objects_api.c_tracing $then
  dbug.enter($$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.' || 'GET_NAMED_OBJECTS');
$if oracle_tools.schema_objects_api.c_debugging $then
  dbug.print(dbug."input", 'p_schema: %s', p_schema);
$end  
$end

  p_schema_object_tab := oracle_tools.t_schema_object_tab();

  for i_idx in 1 .. 4
  loop
$if oracle_tools.schema_objects_api.c_debugging $then
    dbug.print(dbug."info", 'i_idx: %s', i_idx);
$end

    case i_idx
      when 1
      then
        -- queue tables
        for r in
        ( select  q.owner as object_schema
          ,       'AQ_QUEUE_TABLE' as object_type
          ,       q.queue_table as object_name
          from    all_queue_tables q
          where   q.owner = p_schema
        )
        loop
          l_excluded_tables_tab(r.object_name) := true;

$if oracle_tools.schema_objects_api.c_debugging $then
          dbug.print(dbug."info", 'excluding queue table: %s', r.object_name);
$end

$if oracle_tools.pkg_ddl_util.c_get_queue_ddl $then

          p_schema_object_tab.extend(1);
          p_schema_object_tab(p_schema_object_tab.last) :=          
            oracle_tools.t_named_object.create_named_object
            ( p_object_schema => r.object_schema
            , p_object_type => r.object_type
            , p_object_name => r.object_name
            );
$else
          /* ORA-00904: "KU$"."SCHEMA_OBJ"."TYPE": invalid identifier */
          null; 
$end
        end loop;

      when 2
      then
        -- no MATERIALIZED VIEW tables unless PREBUILT
        for r in
        ( select  m.owner as object_schema
          ,       'MATERIALIZED_VIEW' as object_type
          ,       m.mview_name as object_name
          ,       m.build_mode
          from    all_mviews m
          where   m.owner = p_schema
        )
        loop
          if r.build_mode != 'PREBUILT'
          then
            l_excluded_tables_tab(r.object_name) := true;

$if oracle_tools.schema_objects_api.c_debugging $then
            dbug.print(dbug."info", 'excluding materialized view table: %s', r.object_name);
$end
          end if;

          -- this is a special case since we need to exclude first
          p_schema_object_tab.extend(1);
          p_schema_object_tab(p_schema_object_tab.last) :=          
            oracle_tools.t_materialized_view_object(r.object_schema, r.object_name);
        end loop;

      when 3
      then
        -- tables
        for r in
        ( select  t.owner as object_schema
          ,       t.table_name as object_name
          ,       t.tablespace_name
          ,       'TABLE' as object_type
          from    all_tables t
          where   t.owner = p_schema
          and     t.nested = 'NO' -- Exclude nested tables, their DDL is part of their parent table.
          and     ( t.iot_type is null or t.iot_type = 'IOT' ) -- Only the IOT table itself, not an overflow or mapping
                  -- GPA 2017-06-28 #147916863 - As a release operator I do not want comments without table or column.
          and     substr(t.table_name, 1, 5) not in (/*'APEX$', */'MLOG$', 'RUPD$') 
          union -- not union all because since Oracle 12, temporary tables are also shown in all_tables
          -- temporary tables
          select  t.owner as object_schema
          ,       t.object_name
          ,       null as tablespace_name
          ,       t.object_type
          from    all_objects t
          where   t.owner = p_schema
          and     t.object_type = 'TABLE'
          and     t.temporary = 'Y'
$if oracle_tools.pkg_ddl_util.c_exclude_system_objects $then
          and     t.generated = 'N' -- GPA 2016-12-19 #136334705
$end      
                  -- GPA 2017-06-28 #147916863 - As a release operator I do not want comments without table or column.
          and     substr(t.object_name, 1, 5) not in (/*'APEX$', */'MLOG$', 'RUPD$') 
        )
        loop
          if r.object_type <> 'TABLE'
          then
            raise program_error;
          end if;

          if not(l_excluded_tables_tab.exists(r.object_name))
          then
            p_schema_object_tab.extend(1);
            p_schema_object_tab(p_schema_object_tab.last) :=          
              oracle_tools.t_table_object(r.object_schema, r.object_name, r.tablespace_name);

$if oracle_tools.schema_objects_api.c_debugging $then
          else  
            dbug.print(dbug."info", 'not checking since table was excluded: %s', r.object_name);
$end
          end if; 
        end loop;

      when 4
      then
        for r in
        ( /*
          -- Just the base objects, i.e. no constraints, comments, grant nor public synonyms to base objects.
          */
          with obj as
          ( select  obj.owner
            ,       obj.object_type
            ,       obj.object_name
            ,       obj.status
            ,       obj.generated
            ,       obj.temporary
            ,       obj.subobject_name
                    -- use scalar subqueries for a (possible) better performance
            ,       ( select substr(oracle_tools.t_schema_object.dict2metadata_object_type(obj.object_type), 1, 23) from dual ) as md_object_type
--            ,       ( select oracle_tools.t_schema_object.is_a_repeatable(obj.object_type) from dual ) as is_a_repeatable
--            ,       ( select oracle_tools.pkg_ddl_util.is_exclude_name_expr(oracle_tools.t_schema_object.dict2metadata_object_type(obj.object_type), obj.object_name) from dual ) as is_exclude_name_expr
            ,       ( select oracle_tools.pkg_ddl_util.is_dependent_object_type(obj.object_type) from dual ) as is_dependent_object_type
            from    all_objects obj
          )
          select  o.owner as object_schema
          ,       o.md_object_type as object_type
          ,       o.object_name
          from    obj o
          where   o.owner = p_schema
          and     o.object_type not in ('QUEUE', 'MATERIALIZED VIEW', 'TABLE', 'TRIGGER', 'INDEX', 'SYNONYM')
          and     not( o.object_type = 'SEQUENCE' and substr(o.object_name, 1, 5) = 'ISEQ$' )
          and     o.md_object_type member of l_schema_md_object_type_tab
$if oracle_tools.pkg_ddl_util.c_exclude_system_objects $then
          and     o.generated = 'N' -- GPA 2016-12-19 #136334705
$end                
                  -- OWNER         OBJECT_NAME                      SUBOBJECT_NAME
                  -- =====         ===========                      ==============
                  -- ORACLE_TOOLS  oracle_tools.t_table_column_ddl  $VSN_1
          and     o.subobject_name is null
                  -- GPA 2017-06-28 #147916863 - As a release operator I do not want comments without table or column.
          and     o.is_dependent_object_type = 0
        )
        loop
          p_schema_object_tab.extend(1);
          p_schema_object_tab(p_schema_object_tab.last) :=          
            oracle_tools.t_named_object.create_named_object
            ( p_object_schema => r.object_schema
            , p_object_type => r.object_type
            , p_object_name => r.object_name
            );
        end loop;        
    end case;
  end loop;

$if oracle_tools.schema_objects_api.c_tracing $then
$if oracle_tools.schema_objects_api.c_debugging $then
  dbug.print(dbug."output", 'p_schema_object_tab.count: %s', p_schema_object_tab.count);
$end  
  dbug.leave;
$end

$if oracle_tools.schema_objects_api.c_tracing $then
exception
  when others
  then
    dbug.leave_on_error;
    raise;
$end
end get_named_objects;

procedure add
( p_schema_object_tab in oracle_tools.t_schema_object_tab
, p_session_id in t_session_id
, p_schema_object_filter_id in positiven
)
is
  l_last_seq generate_ddl_session_schema_objects.seq%type;
$if oracle_tools.schema_objects_api.c_tracing $then
  l_module_name constant dbug.module_name_t := $$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.' || 'ADD (T_SCHEMA_OBJECT_TAB)';
$end
begin
$if oracle_tools.schema_objects_api.c_tracing $then
  dbug.enter(l_module_name);
$if oracle_tools.schema_objects_api.c_debugging $then
  dbug.print(dbug."input", 'p_session_id: %s; p_schema_object_filter_id: %s', p_session_id, p_schema_object_filter_id);
$end  
$end

  -- insert into SCHEMA_OBJECTS
  -- Note: do not use APPEND hint since that is slow or causes problems
  insert into schema_objects
  ( id
  , obj
  )
    select  t.id
    ,       value(t) as obj
    from    table(p_schema_object_tab) t
    where   t.id not in ( select so.id from oracle_tools.schema_objects so );

$if oracle_tools.schema_objects_api.c_debugging $then
  dbug.print(dbug."info", '# rows inserted into schema_objects: %s', sql%rowcount);
$end  

  -- insert into SCHEMA_OBJECT_FILTER_RESULTS
  insert into schema_object_filter_results
  ( schema_object_filter_id
  , schema_object_id
  , generate_ddl
  )
    select  p_schema_object_filter_id
    ,       t.id as schema_object_id
    ,       sof.obj.matches_schema_object(t.id) as generate_ddl
    from    table(p_schema_object_tab) t
            cross join schema_object_filters sof
    where   ( p_schema_object_filter_id, t.id ) not in
            ( select  schema_object_filter_id
              ,       schema_object_id
              from    schema_object_filter_results
            )
    and     sof.id = p_schema_object_filter_id;

$if oracle_tools.schema_objects_api.c_debugging $then
  dbug.print(dbug."info", '# rows inserted into schema_object_filter_results: %s', sql%rowcount);
$end  

  /*
  -- Now the following tables have data for these parameters:
  -- * SCHEMA_OBJECT_FILTERS (precondition)
  -- * GENERATE_DDL_SESSIONS (precondition)
  -- * SCHEMA_OBJECTS
  -- * SCHEMA_OBJECT_FILTER_RESULTS
  */

  select  nvl(max(gdsso.seq), 0)
  into    l_last_seq
  from    oracle_tools.generate_ddl_session_schema_objects gdsso
  where   gdsso.session_id = p_session_id;

  -- Ignore this entry when MATCHES_SCHEMA_OBJECT returns 0
  insert into generate_ddl_session_schema_objects
  ( session_id
  , seq
  , schema_object_filter_id 
  , schema_object_id
  , last_ddl_time
  )
    select  p_session_id
    -- Since objects are inserted per Oracle session
    -- there is never a problem with another session inserting at the same time for the same session.
    ,       t.seq
    ,       p_schema_object_filter_id
    ,       t.schema_object_id
    ,       -- when DDL has been generated for this last_ddl_time, fix it
            ( select  gd.last_ddl_time
              from    oracle_tools.generated_ddls gd
              where   gd.schema_object_id = t.schema_object_id
              and     gd.last_ddl_time = t.last_ddl_time
            )
    from    ( select  t.id as schema_object_id
              ,       t.last_ddl_time() as last_ddl_time
              ,       rownum + l_last_seq as seq
              from    table(p_schema_object_tab) t -- may contain duplicates (constraints)
                      inner join schema_object_filter_results sofr
                      on sofr.schema_object_filter_id = p_schema_object_filter_id and
                         sofr.schema_object_id = t.id and
                         sofr.generate_ddl = 1 -- ignore objects that do not need to be generated
              where   ( p_session_id, t.id ) not in
                      ( select  /* GENERATE_DDL_SESSION_SCHEMA_OBJECTS$UK$1 */
                                gdsso.session_id
                        ,       gdsso.schema_object_id
                        from    generate_ddl_session_schema_objects gdsso
                      )              
            ) t;

$if oracle_tools.schema_objects_api.c_debugging $then
  dbug.print(dbug."info", '# rows inserted into generate_ddl_session_schema_objects: %s', sql%rowcount);
$end  
  
$if oracle_tools.schema_objects_api.c_tracing $then
  dbug.leave;
exception
  when others
  then
    dbug.leave_on_error;
    raise;
$end
end add;

procedure add_schema_objects
( p_schema_object_filter in oracle_tools.t_schema_object_filter
, p_session_id in t_session_id
, p_schema_object_filter_id in positiven
)
is
$if oracle_tools.schema_objects_api.c_tracing $then
  l_module_name constant dbug.module_name_t := $$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.' || 'ADD_SCHEMA_OBJECTS';
$end  
  l_schema_md_object_type_tab constant oracle_tools.t_text_tab :=
    oracle_tools.pkg_ddl_util.get_md_object_type_tab('SCHEMA');
  l_tmp_schema_object_tab oracle_tools.t_schema_object_tab;
  l_all_schema_object_tab oracle_tools.t_schema_object_tab := oracle_tools.t_schema_object_tab();

  type t_excluded_tables_tab is table of boolean index by all_tables.table_name%type;

  l_excluded_tables_tab t_excluded_tables_tab;
  l_schema constant t_schema_nn := p_schema_object_filter.schema();
  l_grantor_is_schema constant t_numeric_boolean := p_schema_object_filter.grantor_is_schema();
  l_step varchar2(30 char);
  l_longops_rec oracle_tools.api_longops_pkg.t_longops_rec :=
    oracle_tools.api_longops_pkg.longops_init
    ( p_target_desc => 'procedure ' || 'ADD_SCHEMA_OBJECTS'
    , p_totalwork => 10
    , p_op_name => 'what'
    , p_units => 'steps'
    );

  procedure cleanup
  is
  begin
    oracle_tools.api_longops_pkg.longops_done(l_longops_rec);
  end cleanup;
begin
$if oracle_tools.schema_objects_api.c_tracing $then
  dbug.enter(l_module_name);
--$if oracle_tools.schema_objects_api.c_debugging $then
  p_schema_object_filter.print();
--$end  
$end

  for i_idx in c_steps.first .. c_steps.last
  loop
    l_step := c_steps(i_idx);
    -- essential to keep this line here
    l_tmp_schema_object_tab := oracle_tools.t_schema_object_tab();

$if oracle_tools.schema_objects_api.c_tracing $then
    dbug.enter(l_module_name || '.' || l_step);
    dbug.print
    ( dbug."info"
    , 'p_session: %s; schema_objects_api.get_session_id: %s'
    , p_session_id
    , schema_objects_api.get_session_id
    );
$end    

    case l_step
      when "named objects"
      then
        get_named_objects
        ( p_schema => l_schema
        , p_schema_object_tab => l_tmp_schema_object_tab
        );
        -- so they will be part of v_my_schema_objects from this point on
        add
        ( p_schema_object_tab => l_tmp_schema_object_tab
        , p_session_id => p_session_id 
        , p_schema_object_filter_id => p_schema_object_filter_id
        );
        l_tmp_schema_object_tab.delete;

      -- object grants must depend on a base object already gathered (see above)
      when "object grants"
      then
        select  oracle_tools.t_object_grant_object
                ( p_base_object => value(mnso)
                , p_object_schema => null
                , p_grantee => p.grantee
                , p_privilege => p.privilege
                , p_grantable => p.grantable
                )
        bulk collect
        into    l_tmp_schema_object_tab                  
        from    oracle_tools.v_my_named_schema_objects mnso
                inner join oracle_tools.v_my_object_grants_dict p
                on p.base_object_schema = mnso.object_schema() and p.base_object_name = mnso.object_name()
        where   mnso.object_type() not in ( 'PACKAGE_BODY'
                                          , 'TYPE_BODY'
                                          , 'MATERIALIZED_VIEW' -- grants are on underlying tables
                                          ); 
        
      when "comments"
      then
        select  oracle_tools.t_comment_object
                ( p_base_object => treat(value(mnso) as oracle_tools.t_named_object)
                , p_object_schema => c.base_object_schema
                , p_column_name => c.column_name
                )
        bulk collect
        into    l_tmp_schema_object_tab                  
        from    oracle_tools.v_my_named_schema_objects mnso
                inner join oracle_tools.v_my_comments_dict c
                on c.base_object_schema = mnso.object_schema() and
                   c.base_object_type = mnso.object_type() and
                   c.base_object_name = mnso.object_name() and
                   mnso.dict_object_type() in ('TABLE', 'VIEW', 'MATERIALIZED VIEW');

      -- constraints must depend on a base object already gathered
      when "constraints"
      then
        for r in
        ( -- constraints for objects in the same schema
          select  t.*
          from    ( select  value(mnso) as base_object
                    ,       c.object_schema
                    ,       c.object_type
                    ,       c.object_name
                    ,       c.constraint_type
                    ,       c.search_condition
                    from    oracle_tools.v_my_named_schema_objects mnso
                            inner join oracle_tools.v_my_constraints_dict c /* this is where we are interested in */
                            on c.base_object_schema = mnso.object_schema() and c.base_object_name = mnso.object_name()
                    where   mnso.object_type() in ('TABLE', 'VIEW')
                  ) t
        )
        loop
          l_tmp_schema_object_tab.extend(1);

          case r.object_type
            when 'REF_CONSTRAINT'
            then
              l_tmp_schema_object_tab(l_tmp_schema_object_tab.last) :=
                oracle_tools.t_ref_constraint_object
                ( p_base_object => treat(r.base_object as oracle_tools.t_named_object)
                , p_object_schema => r.object_schema
                , p_object_name => r.object_name
                , p_constraint_type => r.constraint_type
                , p_column_names => null
                );

            when 'CONSTRAINT'
            then
              l_tmp_schema_object_tab(l_tmp_schema_object_tab.last) :=
                oracle_tools.t_constraint_object
                ( p_base_object => treat(r.base_object as oracle_tools.t_named_object)
                , p_object_schema => r.object_schema
                , p_object_name => r.object_name
                , p_constraint_type => r.constraint_type
                , p_search_condition => r.search_condition
                );
          end case;
        end loop;

      -- these are not dependent on named objects:
      -- * private synonyms from this schema pointing to a base object in ANY schema possible
      -- * triggers from this schema pointing to a base object in ANY schema possible
      when "synonyms"
      then
        -- private synonyms for this schema which may point to another schema
        select  oracle_tools.t_schema_object.create_schema_object
                ( p_object_schema => s.owner
                , p_object_type => 'SYNONYM'
                , p_object_name => s.synonym_name
                , p_base_object_schema => s.table_owner
                , p_base_object_type =>
                    nvl
                    ( case
                        when s.db_link is null
                        then ( select  max(so.obj.dict_object_type())
                               from    oracle_tools.schema_objects so
                               where   so.obj.object_schema() = s.table_owner
                               and     so.obj.object_name() = s.table_name
                               and     so.obj.object_type() not in ('PACKAGE BODY', 'TYPE BODY', 'MATERIALIZED VIEW')
                             )
                      end
                    , 'TABLE' -- assume its a table when the object could not be found (in this database schema)
                    )
                , p_base_object_name => s.table_name
                )
        bulk collect
        into    l_tmp_schema_object_tab
        from    all_synonyms s
        where   ( s.owner = 'PUBLIC' and s.table_owner = l_schema ) -- public synonyms
        or      ( s.owner = l_schema ); -- private synonyms

      when "triggers"
      then
        select  oracle_tools.t_schema_object.create_schema_object
                ( p_object_schema => t.object_schema
                , p_object_type => t.object_type
                , p_object_name => t.object_name
                , p_base_object_schema => t.base_object_schema
                , p_base_object_type => t.base_object_type
                , p_base_object_name => t.base_object_name
                , p_column_name => t.column_name
                )
        bulk collect
        into    l_tmp_schema_object_tab
        from    ( -- triggers for this schema which may point to another schema
                  select  t.owner as object_schema
                  ,       'TRIGGER' as object_type
                  ,       t.trigger_name as object_name
/* GJP 20170106 see oracle_tools.t_schema_object.chk()
                  -- when the trigger is based on an object in another schema, no base info
                  ,       case when t.owner = t.table_owner then t.table_owner end as base_object_schema
                  ,       case when t.owner = t.table_owner then t.base_object_type end as base_object_type
                  ,       case when t.owner = t.table_owner then t.table_name end as base_object_name
*/
                  ,       t.table_owner as base_object_schema
                  ,       t.base_object_type as base_object_type
                  ,       t.table_name as base_object_name
                  ,       null as column_name
                  from    all_triggers t
                  where   t.owner = l_schema
                  and     t.base_object_type in ('TABLE', 'VIEW')
                ) t;

      -- these are not dependent on named objects:
      -- * indexes from this schema pointing to a base object in ANY schema possible
      when "indexes"
      then
        select  oracle_tools.t_index_object
                ( p_base_object =>
                    oracle_tools.t_named_object.create_named_object
                    ( p_object_schema => i.table_owner
                    , p_object_type => i.table_type
                    , p_object_name => i.table_name
                    )
                , p_object_schema => i.owner
                , p_object_name => i.index_name
                , p_tablespace_name => i.tablespace_name
                )
        bulk collect
        into    l_tmp_schema_object_tab
        from    all_indexes i
        where   i.owner = l_schema
                -- GPA 2017-06-28 #147916863 - As a release operator I do not want comments without table or column.
        and     not(/*substr(i.index_name, 1, 5) = 'APEX$' or */substr(i.index_name, 1, 7) = 'I_MLOG$')
                -- GJP 2022-08-22
                -- When constraint_index = 'YES' the index is created as part of the constraint DDL,
                -- so it will not be listed as a separate DDL statement.
        and     not(i.constraint_index = 'YES')
$if oracle_tools.pkg_ddl_util.c_exclude_system_indexes $then
        and     i.generated = 'N'
$end
        ;
    end case;

$if oracle_tools.schema_objects_api.c_tracing $then
    dbug.print(dbug."info", 'cardinality(l_tmp_schema_object_tab): %s', cardinality(l_tmp_schema_object_tab));
$end

    if l_tmp_schema_object_tab.count > 0
    then
      -- this is real fast
      l_all_schema_object_tab := l_all_schema_object_tab multiset union all l_tmp_schema_object_tab;
    end if;
    oracle_tools.api_longops_pkg.longops_show(l_longops_rec);

$if oracle_tools.schema_objects_api.c_tracing $then
    dbug.print(dbug."info", 'cardinality(l_all_schema_object_tab): %s', cardinality(l_all_schema_object_tab));
$end    

$if oracle_tools.schema_objects_api.c_tracing $then
    dbug.leave;
$end    
  end loop;

  add
  ( p_schema_object_tab => l_all_schema_object_tab
  , p_session_id => p_session_id 
  , p_schema_object_filter_id => p_schema_object_filter_id
  );

  cleanup;

$if oracle_tools.schema_objects_api.c_tracing $then
  dbug.leave;
$end

exception
  when others
  then
    cleanup;
$if oracle_tools.schema_objects_api.c_tracing $then
    dbug.leave_on_error;
$end
    raise;
end add_schema_objects;

procedure cleanup
is
$if oracle_tools.cfg_202410_pkg.c_improve_ddl_generation_performance $then
  pragma autonomous_transaction;
$end  
begin
$if oracle_tools.cfg_202410_pkg.c_improve_ddl_generation_performance $then
  delete from oracle_tools.generate_ddl_sessions t where t.created <= (sys_extract_utc(current_timestamp) - interval '2' day);
  commit;
$else
  null;
$end
end cleanup;

-- PUBLIC

procedure set_session_id
( p_session_id in t_session_id
)
is
begin
  if p_session_id is null
  then
    raise value_error;
  end if;
  g_session_id := p_session_id;
end set_session_id;

function get_session_id
return t_session_id
is
begin
  return g_session_id;
end get_session_id;

procedure add
( p_schema in varchar2 -- The schema name.
, p_object_type in varchar2 -- Filter for object type.
, p_object_names in varchar2 -- A comma separated list of (base) object names.
, p_object_names_include in integer -- How to treat the object name list: include (1), exclude (0) or don't care (null)?
, p_grantor_is_schema in integer -- An extra filter for grants. If the value is 1, only grants with grantor equal to p_schema will be chosen.
, p_exclude_objects in clob -- A newline separated list of objects to exclude (their schema object id actually).
, p_include_objects in clob -- A newline separated list of objects to include (their schema object id actually).
, p_transform_param_list in varchar2 -- A comma separated list of transform parameters, see dbms_metadata.set_transform_param().
, p_schema_object_filter out nocopy oracle_tools.t_schema_object_filter -- the schema object filter
, p_generate_ddl_parameter_id out nocopy oracle_tools.generate_ddl_parameters.id%type
)
is
  l_param_tab1 sys.odcivarchar2list;
  l_param_tab2 sys.odcivarchar2list;
  l_transform_param_list oracle_tools.generate_ddl_parameters.transform_param_list%type;
begin
  p_schema_object_filter :=
    oracle_tools.t_schema_object_filter
    ( p_schema => p_schema
    , p_object_type => p_object_type
    , p_object_names => p_object_names
    , p_object_names_include => p_object_names_include
    , p_grantor_is_schema => p_grantor_is_schema
    , p_exclude_objects => p_exclude_objects
    , p_include_objects => p_include_objects
    );

  l_param_tab1 := oracle_tools.api_pkg.list2collection(p_value_list => p_transform_param_list, p_sep => ',');

  select  distinct upper(t.column_value) as param
  bulk collect
  into    l_param_tab2
  from    table(l_param_tab1) t
  order by
          param;

  l_transform_param_list := ',' || oracle_tools.api_pkg.collection2list(p_value_tab => l_param_tab2, p_sep => ',');

  begin
    select  gdp.id
    into    p_generate_ddl_parameter_id
    from    oracle_tools.generate_ddl_parameters gdp
    where   gdp.transform_param_list = l_transform_param_list;
  exception
    when no_data_found
    then
      insert
      into   oracle_tools.generate_ddl_parameters
      ( transform_param_list
      )
      values
      ( l_transform_param_list
      )
      returning id into p_generate_ddl_parameter_id;
  end;
end add;

procedure add
( p_schema_object_filter in oracle_tools.t_schema_object_filter
, p_generate_ddl_parameter_id in oracle_tools.generate_ddl_parameters.id%type -- the GENERATE_DDL_PARAMETERS.ID
, p_add_schema_objects in boolean
, p_session_id in t_session_id
)
is
  cursor c_sof(b_schema_object_filter_id in positive)
  is
    select  sof.last_modification_time_schema
    from    oracle_tools.schema_object_filters sof
    where   sof.id = b_schema_object_filter_id
    for update of
            sof.updated
    ,       sof.last_modification_time_schema;

  l_last_modification_time_schema_old oracle_tools.schema_object_filters.last_modification_time_schema%type;
  l_last_modification_time_schema_new oracle_tools.schema_object_filters.last_modification_time_schema%type;
  l_schema_object_filter_id positive;
  l_clob constant clob := p_schema_object_filter.serialize();
  l_hash_bucket constant oracle_tools.schema_object_filters.hash_bucket%type :=
    sys.dbms_crypto.hash(l_clob, sys.dbms_crypto.hash_sh1);
  l_hash_bucket_nr oracle_tools.schema_object_filters.hash_bucket_nr%type;
  l_hash_buckets_equal pls_integer;
$if oracle_tools.schema_objects_api.c_tracing $then
  l_module_name constant dbug.module_name_t := $$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.' || 'ADD (T_SCHEMA_OBJECT_FILTER)';
$end
begin
$if oracle_tools.schema_objects_api.c_tracing $then
  dbug.enter(l_module_name);
$if oracle_tools.schema_objects_api.c_debugging $then
  dbug.print(dbug."input", 'p_add_schema_objects: %s', p_add_schema_objects);
  dbug.print(dbug."input", 'p_generate_ddl_parameter_id: %s', p_generate_ddl_parameter_id);  
  dbug.print(dbug."input", 'p_session_id: %s', p_session_id);
$end
$end

  select  max(case when dbms_lob.compare(sof.obj.serialize(), l_clob) = 0 then sof.id end) as id
  ,       nvl(max(sof.hash_bucket_nr), 0) + 1
  ,       count(*)
  into    l_schema_object_filter_id
  ,       l_hash_bucket_nr
  ,       l_hash_buckets_equal
  from    oracle_tools.schema_object_filters sof
  where   sof.hash_bucket = l_hash_bucket;

$if oracle_tools.schema_objects_api.c_debugging $then
  dbug.print
  ( dbug."info"
  , 'l_schema_object_filter_id: %s; l_hash_bucket_nr: %s; l_hash_buckets_equal: %s'
  , l_schema_object_filter_id
  , l_hash_bucket_nr
  , l_hash_buckets_equal
  );
$end

  /*
  ** API_CALL_STACK_PKG before compilation:
  **
  ** OBJECT_TYPE  CREATED           LAST_DDL_TIME     TIMESTAMP           REMARK
  ** -----------  -------           -------------     ---------           ------
  ** PACKAGE      07/12/23 15:56:32 08/12/23 11:49:56 2023-12-08:11:49:56
  ** PACKAGE BODY 07/12/23 15:58:43 08/12/23 11:50:02 2023-12-08:11:50:02
  **
  ** After compile body:
  **
  ** OBJECT_TYPE  CREATED           LAST_DDL_TIME     TIMESTAMP
  ** -----------  -------           -------------     ---------
  ** PACKAGE      07/12/23 15:56:32 08/12/23 11:49:56 2023-12-08:11:49:56 no change
  ** PACKAGE BODY 07/12/23 15:58:43 13/11/24 09:11:02 2023-12-08:11:50:02 LAST_DDL_TIME changed
  **
  ** After compile specification:
  **
  ** OBJECT_TYPE  CREATED           LAST_DDL_TIME     TIMESTAMP
  ** -----------  -------           -------------     ---------
  ** PACKAGE      07/12/23 15:56:32 13/11/24 09:12:38 2023-12-08:11:49:56 LAST_DDL_TIME changed
  ** PACKAGE BODY 07/12/23 15:58:43 13/11/24 09:12:39 2023-12-08:11:50:02 LAST_DDL_TIME changed (1 sec later)
  */

  select  max(o.last_ddl_time)
  into    l_last_modification_time_schema_new
  from    all_objects o
  where   o.owner = p_schema_object_filter.schema;
  
  -- when not found add it
  if l_schema_object_filter_id is null
  then
    insert into oracle_tools.schema_object_filters
    ( hash_bucket
    , hash_bucket_nr
    , obj
    , last_modification_time_schema
    )
    values
    ( l_hash_bucket
    , l_hash_bucket_nr
    , p_schema_object_filter
    , l_last_modification_time_schema_new
    )
    returning id into l_schema_object_filter_id;
  else
    open c_sof(l_schema_object_filter_id);
    fetch c_sof into l_last_modification_time_schema_old;
    if c_sof%notfound
    then raise program_error; -- should not happen
    end if;
    if l_last_modification_time_schema_old <> l_last_modification_time_schema_new
    then
      -- we must recalculate p_schema_object_filter.matches_schema_object() for every object
      delete
      from    oracle_tools.schema_object_filter_results sofr
      where   sofr.schema_object_filter_id = l_schema_object_filter_id;
    end if;
    update  oracle_tools.schema_object_filters sof
    set     sof.last_modification_time_schema = l_last_modification_time_schema_new
    ,       sof.updated = sys_extract_utc(systimestamp)
    where   current of c_sof;
    close c_sof;
  end if;

$if oracle_tools.schema_objects_api.c_debugging $then
  dbug.print(dbug."info", 'l_schema_object_filter_id: %s', l_schema_object_filter_id);
$end

  -- either insert or update GENERATE_DDL_SESSIONS
  if get_schema_object_filter_id(p_session_id => p_session_id) is null
  then
    insert into generate_ddl_sessions
    ( session_id
    , schema_object_filter_id
    , generate_ddl_parameter_id
    )
    values
    ( p_session_id
    , l_schema_object_filter_id
    , p_generate_ddl_parameter_id
    );
$if oracle_tools.schema_objects_api.c_debugging $then
    dbug.print(dbug."info", '# rows inserted into generate_ddl_sessions: %s', sql%rowcount);
$end
  else
    -- make room for new objects/ddls
    delete
    from    generate_ddl_session_schema_objects gdsso
    where   gdsso.session_id = p_session_id;
    
$if oracle_tools.schema_objects_api.c_debugging $then
    dbug.print(dbug."info", '# rows deleted from generate_ddl_session_schema_objects: %s', sql%rowcount);
$end

    update  generate_ddl_sessions gds
    set     gds.schema_object_filter_id = l_schema_object_filter_id
    ,       gds.generate_ddl_parameter_id = p_generate_ddl_parameter_id
    ,       gds.updated = sys_extract_utc(systimestamp)
    where   gds.session_id = p_session_id;
    
$if oracle_tools.schema_objects_api.c_debugging $then
    dbug.print(dbug."info", '# rows updated for generate_ddl_sessions: %s', sql%rowcount);
$end
  end if;

  if p_add_schema_objects
  then
    add_schema_objects
    ( p_schema_object_filter => p_schema_object_filter
    , p_session_id => p_session_id
    , p_schema_object_filter_id => l_schema_object_filter_id
    );
  end if;

$if oracle_tools.schema_objects_api.c_tracing $then
  dbug.leave;
exception
  when others
  then
    dbug.leave_on_error;
    raise;
$end
end add;

procedure add
( p_schema_object in oracle_tools.t_schema_object
, p_session_id in t_session_id
, p_ignore_dup_val_on_index in boolean
)
is
  l_schema_object_filter_id constant positive := get_schema_object_filter_id(p_session_id => p_session_id);
  l_schema_object_id constant oracle_tools.schema_objects.id%type := p_schema_object.id;
  l_found pls_integer;
$if oracle_tools.schema_objects_api.c_tracing $then
  l_module_name constant dbug.module_name_t := $$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.' || 'ADD (T_SCHEMA_OBJECT)';
$end
begin
$if oracle_tools.schema_objects_api.c_tracing $then
  dbug.enter(l_module_name);
$end

  -- check precondition (in GENERATE_DDL_SESSIONS and thus SCHEMA_OBJECT_FILTERS)
  if l_schema_object_filter_id is null
  then
    raise program_error;
  end if;
  
  -- retrieve from or insert into SCHEMA_OBJECTS
  begin
    select  1
    into    l_found
    from    oracle_tools.schema_objects so
    where   so.id = l_schema_object_id;
  exception
    when no_data_found
    then insert into schema_objects(id, obj) values (p_schema_object.id, p_schema_object);
  end;

  -- retrieve from or insert into SCHEMA_OBJECT_FILTER_RESULTS
  begin
    select  1
    into    l_found
    from    oracle_tools.schema_object_filter_results sofr
    where   sofr.schema_object_filter_id = l_schema_object_filter_id
    and     sofr.schema_object_id = l_schema_object_id;
  exception
    when no_data_found
    then
      insert into schema_object_filter_results
      ( schema_object_filter_id
      , schema_object_id
      , generate_ddl
      )
      values
      ( l_schema_object_filter_id
      , l_schema_object_id
      , ( select sof.obj.matches_schema_object(l_schema_object_id) from schema_object_filters sof where sof.id = l_schema_object_filter_id )
      );
  end;

  /*
  -- Now the following tables have data for these parameters:
  -- * SCHEMA_OBJECT_FILTERS (precondition)
  -- * GENERATE_DDL_SESSIONS (precondition)
  -- * SCHEMA_OBJECTS
  -- * SCHEMA_OBJECT_FILTER_RESULTS
  */

  -- Ignore this entry when MATCHES_SCHEMA_OBJECT returns 0
  begin
    select  1
    into    l_found
    from    oracle_tools.schema_object_filter_results sofr
    where   sofr.schema_object_filter_id = l_schema_object_filter_id
    and     sofr.schema_object_id = l_schema_object_id
    and     sofr.generate_ddl = 1;
  exception
    when no_data_found
    then -- no match
      l_found := 0;
  end;

  if l_found = 1
  then
    begin
      insert into generate_ddl_session_schema_objects
      ( session_id
      , schema_object_filter_id 
      , seq
      , schema_object_id
      , last_ddl_time
      )
      values
      ( p_session_id
      , l_schema_object_filter_id
        -- Since objects are inserted per Oracle session
        -- there is never a problem with another session inserting at the same time for the same session.
      , ( select  nvl(max(gdsso.seq), 0) + 1
          from    oracle_tools.generate_ddl_session_schema_objects gdsso
          where   gdsso.session_id = p_session_id
        )
      , l_schema_object_id
      , ( select  gd.last_ddl_time
          from    oracle_tools.generated_ddls gd
          where   gd.schema_object_id = l_schema_object_id
          and     gd.last_ddl_time = p_schema_object.last_ddl_time()
        )
      );
    exception
      when dup_val_on_index
      then
        if not p_ignore_dup_val_on_index
        then
          raise_application_error
          ( oracle_tools.pkg_ddl_error.c_duplicate_item
          , utl_lms.format_message
            ( 'Could not add duplicate GENERATE_DDL_SESSION_SCHEMA_OBJECTS row with object id %s, since it already exists at (session_id=%s, seq=%s)'
            , l_schema_object_id
            , to_char(p_session_id)
            , to_char(find_schema_object_by_object_id(p_schema_object_id => p_schema_object.id, p_session_id => p_session_id).seq)
            )
          , true              
          );
        end if;
    end;
  end if;
$if oracle_tools.schema_objects_api.c_tracing $then
  dbug.leave;
exception
  when others
  then
    dbug.leave_on_error;
    raise;
$end
end add;

procedure add
( p_schema_object_cursor in t_schema_object_cursor
, p_session_id in t_session_id
, p_ignore_dup_val_on_index in boolean
)
is
  l_schema_object_tab t_schema_object_tab;
  l_limit constant simple_integer := 100;
$if oracle_tools.schema_objects_api.c_tracing $then
  l_module_name constant dbug.module_name_t := $$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.' || 'ADD (T_SCHEMA_OBJECT_CURSOR)';
$end
begin
$if oracle_tools.schema_objects_api.c_tracing $then
  dbug.enter(l_module_name);
$end

  <<fetch_loop>>
  loop
    fetch p_schema_object_cursor bulk collect into l_schema_object_tab limit l_limit;
    if l_schema_object_tab.count > 0
    then
      for i_idx in l_schema_object_tab.first .. l_schema_object_tab.last
      loop
        -- simple: bulk dml may improve speed but helas
        add
        ( p_schema_object => l_schema_object_tab(i_idx)
        , p_session_id => p_session_id
        , p_ignore_dup_val_on_index => p_ignore_dup_val_on_index
        );
      end loop;
    end if;
    exit fetch_loop when l_schema_object_tab.count < l_limit; -- netx fetch will return 0 rows
  end loop;

$if oracle_tools.schema_objects_api.c_tracing $then
  dbug.leave;
exception
  when others
  then
    dbug.leave_on_error;
    raise;
$end
end add;

procedure add
( p_schema_ddl in oracle_tools.t_schema_ddl
, p_session_id in t_session_id
)
is
  l_generated_ddl_id oracle_tools.generated_ddls.id%type;
$if oracle_tools.schema_objects_api.c_tracing $then
  l_module_name constant dbug.module_name_t := $$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.' || 'ADD (T_SCHEMA_DDL)';
$end
begin
$if oracle_tools.schema_objects_api.c_tracing $then
  dbug.enter(l_module_name);
$end

  -- input checks
  case
    when p_schema_ddl is null
    then raise value_error;
    when p_schema_ddl.obj is null
    then raise value_error;
    when p_schema_ddl.obj.id is null
    then raise value_error;
    when p_session_id is null
    then raise value_error;
    else null;
  end case;

  p_schema_ddl.chk(null);

  if cardinality(p_schema_ddl.ddl_tab) > 0
  then
    begin
      select  gd.id
      into    l_generated_ddl_id
      from    oracle_tools.generated_ddls gd
      where   gd.schema_object_id = p_schema_ddl.obj.id
      and     gd.last_ddl_time = p_schema_ddl.obj.last_ddl_time;
    exception
      when no_data_found
      then
        insert into oracle_tools.generated_ddls
        ( schema_object_id
        , last_ddl_time
        )
        values
        ( p_schema_ddl.obj.id
        , p_schema_ddl.obj.last_ddl_time
        )
        returning id into l_generated_ddl_id;
    end;
      
    for i_ddl_idx in p_schema_ddl.ddl_tab.first .. p_schema_ddl.ddl_tab.last
    loop
      insert into generated_ddl_statements
      ( generated_ddl_id
      , ddl#
      , verb
      )
      values
      ( l_generated_ddl_id
      , p_schema_ddl.ddl_tab(i_ddl_idx).ddl#()
      , p_schema_ddl.ddl_tab(i_ddl_idx).verb()
      );
      if cardinality(p_schema_ddl.ddl_tab(i_ddl_idx).text_tab) > 0
      then
        for i_chunk_idx in p_schema_ddl.ddl_tab(i_ddl_idx).text_tab.first
                           ..
                           p_schema_ddl.ddl_tab(i_ddl_idx).text_tab.last
        loop
          insert into generated_ddl_statement_chunks
          ( generated_ddl_id
          , ddl#
          , chunk#
          , chunk
          )
          values
          ( l_generated_ddl_id
          , p_schema_ddl.ddl_tab(i_ddl_idx).ddl#()
          , i_chunk_idx
          , p_schema_ddl.ddl_tab(i_ddl_idx).text_tab(i_chunk_idx)
          );
        end loop;
      end if;
    end loop;
  else
    raise no_data_found;
  end if;

$if oracle_tools.schema_objects_api.c_tracing $then
  dbug.leave;
exception
  when others
  then
    dbug.leave_on_error;
    raise;
$end
end add;

procedure add
( p_schema_ddl_tab in oracle_tools.t_schema_ddl_tab
, p_session_id in t_session_id
)
is
  l_limit constant simple_integer := 100;

$if oracle_tools.schema_objects_api.c_tracing $then
  l_module_name constant dbug.module_name_t := $$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.' || 'ADD (T_SCHEMA_DDL_TAB)';
$end
begin
$if oracle_tools.schema_objects_api.c_tracing $then
  dbug.enter(l_module_name);
$end

  if p_schema_ddl_tab.count > 0
  then
    -- ORA-12899: value too large for column "ORACLE_TOOLS"."GENERATE_DDL_SESSION_SCHEMA_OBJECTS"."DDL"
    for i_idx in p_schema_ddl_tab.first .. p_schema_ddl_tab.last
    loop
      add
      ( p_schema_ddl => p_schema_ddl_tab(i_idx)
      , p_session_id => p_session_id
      );
    end loop;
  end if;

$if oracle_tools.schema_objects_api.c_tracing $then
  dbug.leave;
exception
  when others
  then
    dbug.leave_on_error;
    raise;
$end
end add;

procedure add
( p_schema in varchar2
, p_transform_param_list in varchar2
, p_object_schema in varchar2
, p_object_type in varchar2
, p_base_object_schema in varchar2
, p_base_object_type in varchar2
, p_object_name_tab in oracle_tools.t_text_tab
, p_base_object_name_tab in oracle_tools.t_text_tab
, p_nr_objects in integer
, p_session_id in t_session_id
)
is
begin
  insert into oracle_tools.generate_ddl_session_batches
  ( session_id
  , seq
  , schema
  , transform_param_list
  , object_schema
  , object_type
  , base_object_schema
  , base_object_type
  , object_name_tab
  , base_object_name_tab
  , nr_objects
  )
  values
  ( p_session_id
  , (select nvl(max(gdsb.seq), 0) + 1 from oracle_tools.generate_ddl_session_batches gdsb where gdsb.session_id = p_session_id)
  , p_schema
  , p_transform_param_list
  , p_object_schema
  , p_object_type
  , p_base_object_schema
  , p_base_object_type
  , p_object_name_tab
  , p_base_object_name_tab
  , p_nr_objects
  );
end add;

function find_schema_object_by_seq
( p_seq in integer
, p_session_id in t_session_id
)
return generate_ddl_session_schema_objects%rowtype
is
  l_rec generate_ddl_session_schema_objects%rowtype;
begin
  select  gdsso.*
  into    l_rec
  from    oracle_tools.generate_ddl_session_schema_objects gdsso
  where   gdsso.session_id = p_session_id
  and     gdsso.seq = p_seq;

  return l_rec;
end find_schema_object_by_seq;

function find_schema_object_by_object_id
( p_schema_object_id in varchar2
, p_session_id in t_session_id
)
return generate_ddl_session_schema_objects%rowtype
is
  l_rec generate_ddl_session_schema_objects%rowtype;
begin
  select  gdsso.*
  into    l_rec
  from    oracle_tools.generate_ddl_session_schema_objects gdsso
  where   gdsso.session_id = p_session_id
  and     gdsso.schema_object_id = p_schema_object_id;

  return l_rec;
end find_schema_object_by_object_id;

procedure get_schema_objects
( p_schema_object_filter in oracle_tools.t_schema_object_filter
, p_generate_ddl_parameter_id in oracle_tools.generate_ddl_parameters.id%type -- the GENERATE_DDL_PARAMETERS.ID
, p_schema_object_tab out nocopy oracle_tools.t_schema_object_tab
)
is
  l_schema_object_filter_id positiven := 1;
$if oracle_tools.schema_objects_api.c_tracing $then
  l_module_name constant dbug.module_name_t := $$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.' || 'GET_SCHEMA_OBJECTS (1)';
$end
begin
$if oracle_tools.schema_objects_api.c_tracing $then
  dbug.enter(l_module_name);
$end

  add
  ( p_schema_object_filter => p_schema_object_filter
  , p_generate_ddl_parameter_id => p_generate_ddl_parameter_id
  , p_add_schema_objects => true
  );
  select  value(t) as obj
  bulk collect
  into    p_schema_object_tab
  from    oracle_tools.v_my_schema_objects t;

$if oracle_tools.schema_objects_api.c_tracing $then
  dbug.leave;
exception
  when others
  then
    dbug.leave_on_error;
    raise;
$end
end get_schema_objects;

function get_schema_objects
( p_schema in varchar2
, p_object_type in varchar2
, p_object_names in varchar2
, p_object_names_include in integer
, p_grantor_is_schema in integer
, p_exclude_objects in clob
, p_include_objects in clob
, p_transform_param_list in varchar2
)
return oracle_tools.t_schema_object_tab
pipelined
is
  pragma autonomous_transaction;
  
  l_schema_object_filter oracle_tools.t_schema_object_filter := null;
  l_generate_ddl_parameter_id oracle_tools.generate_ddl_parameters.id%type;
  l_schema_object_filter_id positiven := 1;
  l_program constant t_module := 'function ' || 'GET_SCHEMA_OBJECTS'; -- geen schema omdat l_program in dbms_application_info wordt gebruikt

  -- dbms_application_info stuff
  l_longops_rec oracle_tools.api_longops_pkg.t_longops_rec :=
    oracle_tools.api_longops_pkg.longops_init
    ( p_target_desc => l_program
    , p_op_name => 'fetch'
    , p_units => 'objects'
    );

  procedure cleanup
  is
  begin
    -- on error save so we can verify else rollback because we do not need the data
    oracle_tools.api_longops_pkg.longops_done(l_longops_rec);
  end cleanup;
begin
$if oracle_tools.schema_objects_api.c_tracing $then
  dbug.enter($$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.' || 'GET_SCHEMA_OBJECTS');
$end

  add
  ( p_schema => p_schema
  , p_object_type => p_object_type
  , p_object_names => p_object_names
  , p_object_names_include => p_object_names_include
  , p_grantor_is_schema => p_grantor_is_schema
  , p_exclude_objects => p_exclude_objects
  , p_include_objects => p_include_objects
  , p_transform_param_list => p_transform_param_list
  , p_schema_object_filter => l_schema_object_filter
  , p_generate_ddl_parameter_id => l_generate_ddl_parameter_id
  );
  add
  ( p_schema_object_filter => l_schema_object_filter
  , p_generate_ddl_parameter_id => l_generate_ddl_parameter_id
  , p_add_schema_objects => true
  );

  commit; -- must be done before the pipe row

  for r in ( select value(t) as obj from oracle_tools.v_my_schema_objects t )
  loop
    pipe row (r.obj);
    oracle_tools.api_longops_pkg.longops_show(l_longops_rec);
  end loop;

  cleanup;

$if oracle_tools.schema_objects_api.c_tracing $then
  dbug.leave;
$end

  return; -- essential for pipelined functions
exception
  when no_data_needed
  then
    -- not a real error, just a way to some cleanup
    cleanup;
$if oracle_tools.schema_objects_api.c_tracing $then
    dbug.leave;
$end

  when no_data_found
  then
    cleanup;
    commit;
$if oracle_tools.schema_objects_api.c_tracing $then
    dbug.leave_on_error;
$end
    oracle_tools.pkg_ddl_error.reraise_error(l_program);
    raise; -- to keep the compiler happy

  when others
  then
    cleanup;
    commit;
$if oracle_tools.schema_objects_api.c_tracing $then
    dbug.leave_on_error;
$end
    raise;
end get_schema_objects;

procedure default_match_perc_threshold
( p_match_perc_threshold in integer
)
is
begin
  g_default_match_perc_threshold := p_match_perc_threshold;
end default_match_perc_threshold;

function match_perc
( p_session_id in t_session_id
)
return integer
deterministic
is
  l_nr_objects_generate_ddl number;
  l_nr_objects number;
begin
  select  sum(t.generate_ddl) as nr_objects_generate_ddl
  ,       count(*) as nr_objects
  into    l_nr_objects_generate_ddl
  ,       l_nr_objects
  from    oracle_tools.v_all_schema_objects t
  where   t.session_id = p_session_id;
  
  return case when l_nr_objects > 0 then trunc((100 * l_nr_objects_generate_ddl) / l_nr_objects) else null end;
end match_perc;

function match_perc_threshold
return integer
deterministic
is
begin
  return g_default_match_perc_threshold;
end;

$if oracle_tools.cfg_pkg.c_testing $then

procedure ut_get_schema_objects
is
  pragma autonomous_transaction;

  l_schema_object_tab0 oracle_tools.t_schema_object_tab;
  l_schema_object_tab1 oracle_tools.t_schema_object_tab;
  l_schema t_schema;

  l_count pls_integer;

  l_program constant t_module := 'UT_GET_SCHEMA_OBJECTS';
begin
$if oracle_tools.schema_objects_api.c_debugging $then
  dbug.enter($$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.' || l_program);
$end

$if oracle_tools.pkg_ddl_util.c_get_queue_ddl $then

  -- check queue tables
  for r in
  ( select  q.owner
    ,       q.queue_table
    from    all_queue_tables q
    where   rownum = 1
  )
  loop
    for i_test in 1..2
    loop
      select  count(*)
      into    l_count
      from    table
              ( oracle_tools.schema_objects_api.get_schema_objects
                ( r.owner
                , case i_test when 1 then null else 'AQ_QUEUE_TABLE' end
                , r.queue_table
                , 1
                )
              ) t
      where   t.object_type() in ('TABLE', 'AQ_QUEUE_TABLE');

      ut.expect(l_count, l_program || '#queue table count#' || r.owner || '.' || r.queue_table || '#' || i_test).to_equal(1);
    end loop;
  end loop;

$else

    /* ORA-00904: "KU$"."SCHEMA_OBJ"."TYPE": invalid identifier */

$end

  -- check materialized views, prebuilt or not
  for r in
  ( select  min(m.owner||'.'||m.mview_name) as mview_name
    ,       m.build_mode
    from    all_mviews m
    group by
            m.build_mode
  )
  loop
    for i_test in 1..3
    loop
      select  count(*)
      into    l_count
      from    table
              ( oracle_tools.schema_objects_api.get_schema_objects
                ( substr(r.mview_name, 1, instr(r.mview_name, '.')-1)
                , case i_test when 1 then null when 2 then 'MATERIALIZED_VIEW' when 3 then 'TABLE' end
                , substr(r.mview_name, instr(r.mview_name, '.')+1)
                , 1
                )
              ) t
      where   t.object_type() in ('TABLE', 'MATERIALIZED_VIEW');

      ut.expect
      ( l_count
      , l_program || '#mview count#' || r.mview_name || '#' || r.build_mode || '#' || i_test
      ).to_equal( case
                    when r.build_mode = 'PREBUILT'
                    then
                      case i_test
                        when 1
                        then 2 -- table and mv returned
                        else 1 -- else table or mv
                      end
                    else
                      case i_test
                        when 3
                        then 0 -- nothing returned
                        else 1 -- mv returned
                      end
                  end
                );
    end loop;
  end loop;

  -- check synonyms, indexes and triggers from this schema base on on abject from another schema
  for r in
  ( select  min(s.owner||'.'||s.synonym_name) as fq_object_name
    ,       'SYNONYM' as object_type
    from    all_synonyms s
    where   s.owner <> s.table_owner
    and     s.owner = user
    and     s.table_name is not null
    union
    select  min(t.owner||'.'||t.trigger_name) as fq_object_name
    ,       'TRIGGER' as object_type
    from    all_triggers t
    where   t.owner <> t.table_owner
    and     t.owner = user
    and     t.table_name is not null
    union
    select  min(i.owner||'.'||i.index_name) as fq_object_name
    ,       'INDEX' as object_type
    from    all_indexes i
    where   i.owner <> i.table_owner
    and     i.owner = user
    and     i.table_name is not null
$if oracle_tools.pkg_ddl_util.c_exclude_system_indexes $then
    and     i.generated = 'N'
$end      
  )
  loop
    if r.fq_object_name is not null
    then
      select  count(*)
      into    l_count
      from    table
              ( oracle_tools.schema_objects_api.get_schema_objects
                ( substr(r.fq_object_name, 1, instr(r.fq_object_name, '.')-1)
                , r.object_type
                , substr(r.fq_object_name, instr(r.fq_object_name, '.')+1)
                , 1
                )
              ) t;

      ut.expect
      ( l_count
      , l_program || '#object based on another schema count#' || r.fq_object_name
      ).to_equal(1);
    end if;
  end loop;

  commit;

$if oracle_tools.schema_objects_api.c_debugging $then
  dbug.leave;
exception
  when others
  then
    dbug.leave_on_error;
    raise;
$end
end ut_get_schema_objects;

procedure ut_get_schema_object_filter
is
  l_schema_object_id_tab sys.odcivarchar2list;
  l_expected sys_refcursor;
  l_actual sys_refcursor;

  l_program constant t_module := $$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.' || 'UT_GET_SCHEMA_OBJECT_FILTER';
begin
$if oracle_tools.schema_objects_api.c_debugging $then
  dbug.enter(l_program);
$end

  select  id
  bulk collect
  into    l_schema_object_id_tab
  from    ( select  t.id as id
            ,       row_number() over (partition by t.object_schema(), t.object_type() order by t.object_name() asc) as nr
            from    table
                    ( oracle_tools.schema_objects_api.get_schema_objects
                      ( p_schema => user
                      , p_object_type => null
                      , p_object_names => null
                      , p_object_names_include => null
                      , p_grantor_is_schema => 0
                      , p_exclude_objects => null
                      , p_include_objects => null
                      )
                    ) t
            order by
                    t.object_schema()
            ,       t.object_type()
          )
  where   nr = 1  
  ;

  for i_idx in l_schema_object_id_tab.first .. l_schema_object_id_tab.last
  loop
$if oracle_tools.schema_objects_api.c_debugging $then
    dbug.print(dbug."info", 'id: %s', l_schema_object_id_tab(i_idx));
$end

    open l_expected for
      select  l_schema_object_id_tab(i_idx) as id
      from    dual;
    open l_actual for
      select  t.id as id
      from    table
              ( oracle_tools.schema_objects_api.get_schema_objects
                ( p_schema => user
                , p_include_objects => to_clob(l_schema_object_id_tab(i_idx))
                )
              ) t;
    ut.expect(l_actual, 'include ' || l_schema_object_id_tab(i_idx)).to_equal(l_expected);

    open l_expected for
      select  l_schema_object_id_tab(i_idx) as id
      from    dual
      where   0 = 1;
    open l_actual for
      select  t.id as id
      from    table
              ( oracle_tools.schema_objects_api.get_schema_objects
                ( p_schema => user
                , p_exclude_objects => to_clob(l_schema_object_id_tab(i_idx))
                , p_include_objects => to_clob(l_schema_object_id_tab(i_idx))
                )
              ) t;
    ut.expect(l_actual, 'exclude and include ' || l_schema_object_id_tab(i_idx)).to_equal(l_expected);
end loop;

$if oracle_tools.schema_objects_api.c_debugging $then
  dbug.leave;
exception
  when others
  then
    dbug.leave_on_error;
    raise;
$end
end ut_get_schema_object_filter;

$end

begin
  cleanup;
END SCHEMA_OBJECTS_API;
/

