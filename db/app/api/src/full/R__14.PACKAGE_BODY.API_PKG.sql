CREATE OR REPLACE PACKAGE BODY "API_PKG" IS -- -*-coding: utf-8-*-

function get_object_no_dependencies_tab
return t_object_natural_tab;

c_object_no_dependencies_tab constant t_object_natural_tab := get_object_no_dependencies_tab; -- initialisation

function get_object_no_dependencies_tab
return t_object_natural_tab
is
  l_object_no_dependencies_tab t_object_natural_tab; -- initialisation
begin
  return l_object_no_dependencies_tab;
end get_object_no_dependencies_tab;

/*
-- see depth-first search algorithm in https://en.wikipedia.org/wiki/Topological_sorting
--
-- code                                                       | marker
-- ====                                                       | ======
-- function visit(node n)                                     |
--    if n has a temporary mark then stop (not a DAG)         | A
--    if n is not marked (i.e. has not been visited yet) then | B
--        mark n temporarily                                  | C
--        for each node m with an graph from n to m do        | D
--            visit(m)                                        | E
--        mark n permanently                                  | F
--        unmark n temporarily                                | G
--        add n to head of L                                  | H
*/
procedure visit
( p_graph in t_graph
, p_n in t_object
, p_unmarked_nodes in out nocopy t_object_natural_tab
, p_marked_nodes in out nocopy t_object_natural_tab
, p_result in out nocopy dbms_sql.varchar2_table
, p_error_n out nocopy t_object
)
is
  l_m t_object;
begin
  p_error_n := null;

  if p_marked_nodes.exists(p_n)
  then
    if p_marked_nodes(p_n) = 1 /* A */
    then
      -- node has been visited before
      p_error_n := p_n;
      return;
    end if;
  else
    if not p_unmarked_nodes.exists(p_n)
    then
      raise program_error;
    end if;

    /* B */
    p_marked_nodes(p_n) := 1; -- /* C */

    /* D */
    if p_graph.exists(p_n)
    then
      l_m := p_graph(p_n).first;
      while l_m is not null
      loop
        visit
        ( p_graph => p_graph
        , p_n => l_m
        , p_unmarked_nodes => p_unmarked_nodes
        , p_marked_nodes => p_marked_nodes
        , p_result => p_result
        , p_error_n => p_error_n
        ); /* E */
        if p_error_n is not null
        then
          return;
        end if;
        l_m := p_graph(p_n).next(l_m);
      end loop;
    end if;

    p_marked_nodes(p_n) := 2; -- /* F */
    p_unmarked_nodes.delete(p_n); -- /* G */
    p_result(-p_result.count) := p_n; /* H */
  end if;
end visit;

procedure tsort
( p_graph in t_graph
, p_result out nocopy dbms_sql.varchar2_table /* I */
, p_error_n out nocopy t_object
)
is
  l_unmarked_nodes t_object_natural_tab;
  l_marked_nodes t_object_natural_tab; -- l_marked_nodes(n) = 1 (temporarily marked) or 2 (permanently marked)
  l_n t_object;
  l_m t_object;
begin
$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.api_pkg.c_debugging >= 1 $then
  dbug.enter($$PLSQL_UNIT || '.TSORT');
$end

  /*
  -- see depth-first search algorithm in https://en.wikipedia.org/wiki/Topological_sorting
  --
  -- code                                               | marker
  -- ====                                               | ======
  -- L := Empty list that will contain the sorted nodes | I
  -- while there are unmarked nodes do                  | J
  --    select an unmarked node n                       | K
  --    visit(n)                                        | L
  */

  /* I */
  if p_result.count <> 0
  then
    raise program_error;
  end if;

  /* determine unmarked nodes: all node graphs */
  l_n := p_graph.first;
  while l_n is not null
  loop
    l_unmarked_nodes(l_n) := 0; -- n not marked
    l_m := p_graph(l_n).first;
    while l_m is not null
    loop
      l_unmarked_nodes(l_m) := 0; -- m not marked
      l_m := p_graph(l_n).next(l_m);
    end loop;
    l_n := p_graph.next(l_n);
  end loop;
  /* all nodes are unmarked */

  while l_unmarked_nodes.count > 0 /* J */
  loop
    /* L */
    PRAGMA INLINE (visit, 'YES');
    visit
    ( p_graph => p_graph
    , p_n => l_unmarked_nodes.first /* K */
    , p_unmarked_nodes => l_unmarked_nodes
    , p_marked_nodes => l_marked_nodes
    , p_result => p_result
    , p_error_n => p_error_n
    );
    exit when p_error_n is not null;
  end loop;

$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.api_pkg.c_debugging >= 1 $then
  dbug.print(dbug."output", 'p_error_n: %s', p_error_n);
  dbug.leave;
exception
  when others
  then
    dbug.leave_on_error;
    raise;
$end
end tsort;

$if cfg_pkg.c_testing $then

function called_by_utplsql
return boolean
is
  l_dynamic_depth pls_integer := utl_call_stack.dynamic_depth;
begin
  -- API_PKG.UT_SETUP
  -- API_PKG.UT_SETUP_AUTONOMOUS_TRANSACTION
  -- API_PKG.UT_SETUP
  -- BNS_PKG_CPN.UT_SETUP
  -- __anonymous_block
  -- DBMS_SQL.EXECUTE
  -- UT_EXECUTABLE.DO_EXECUTE
  -- UT_SUITE.DO_EXECUTE
  -- UT_SUITE_ITEM.DO_EXECUTE
  -- UT_LOGICAL_SUITE.DO_EXECUTE
  -- UT_RUN.DO_EXECUTE
  -- UT_SUITE_ITEM.DO_EXECUTE
  -- UT_RUNNER.RUN
  -- __anonymous_block

  for i_idx in 1 .. l_dynamic_depth
  loop
    if utl_call_stack.subprogram(i_idx)(1) = 'UT_EXECUTABLE'
    then
      return true;
    end if;
  end loop;

  return false;
end called_by_utplsql;

procedure ut_setup
( p_br_package_tab in data_br_pkg.t_br_package_tab
, p_insert_procedure in all_procedures.object_name%type
)
is
$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.api_pkg.c_debugging >= 1 $then
  l_dynamic_depth pls_integer := utl_call_stack.dynamic_depth;
$end  
begin
$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.api_pkg.c_debugging >= 1 $then
  dbug.enter($$PLSQL_UNIT || '.UT_SETUP');

  for i_idx in 1 .. l_dynamic_depth
  loop
    dbug.print
    ( dbug."info"
    , 'dynamic depth: %s; lexical depth: %s; owner: %s; unit line: %s; subprogram: %s'
    , i_idx
    , utl_call_stack.lexical_depth(i_idx)
    , utl_call_stack.owner(i_idx)
    , utl_call_stack.unit_line(i_idx)
    , utl_call_stack.concatenate_subprogram(utl_call_stack.subprogram(i_idx))
    );
  end loop;
$end

  data_br_pkg.check_br(p_br_package_tab => p_br_package_tab, p_br_name => '%', p_enable => true);
  
  if p_insert_procedure is not null
  then
    execute immediate 'begin ' || oracle_tools.data_api_pkg.dbms_assert$sql_object_name(p_insert_procedure, 'procedure') || '; end;';
  end if;

$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.api_pkg.c_debugging >= 1 $then
  dbug.leave;
exception
  when others
  then
    dbug.leave_on_error;
    raise;
$end
end ut_setup;

procedure ut_setup_at -- ut_setup_autonomous_transaction too long before Oracle 12CR2
( p_br_package_tab in data_br_pkg.t_br_package_tab
, p_insert_procedure in all_procedures.object_name%type
)
is
  pragma autonomous_transaction;
begin
  -- enable_br('%', true);
  data_br_pkg.restore_data_integrity(p_br_package_tab => p_br_package_tab);
  ut_setup(p_br_package_tab, p_insert_procedure);
  commit;
end ut_setup_at;

procedure ut_teardown
( p_br_package_tab in data_br_pkg.t_br_package_tab
, p_delete_procedure in all_procedures.object_name%type
)
is
begin
  data_br_pkg.check_br(p_br_package_tab => p_br_package_tab, p_br_name => '%', p_enable => true);
  if p_delete_procedure is not null
  then
    execute immediate 'begin ' || oracle_tools.data_api_pkg.dbms_assert$sql_object_name(p_delete_procedure, 'procedure') || '; end;';
  end if;
end ut_teardown;

procedure ut_teardown_at -- ut_teardown_autonomous_transaction too long before Oracle 12CR2
( p_br_package_tab in data_br_pkg.t_br_package_tab
, p_delete_procedure in all_procedures.object_name%type
)
is
begin
  data_br_pkg.enable_br(p_br_package_tab => p_br_package_tab, p_br_name => '%', p_enable => true);
  ut_teardown(p_br_package_tab, p_delete_procedure);
  commit;
end ut_teardown_at;

$end -- $if cfg_pkg.c_testing $then

-- GLOBAL

function get_data_owner
return all_objects.owner%type
is
begin
  return data_api_pkg.get_owner;
end get_data_owner;

function show_cursor
( p_cursor in t_cur
)
return t_tab
pipelined
is
  l_limit constant pls_integer := 100;
  l_tab t_tab;
begin
$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.api_pkg.c_debugging >= 1 $then
  dbug.enter($$PLSQL_UNIT || '.SHOW_CURSOR');
$end

  loop
    fetch p_cursor bulk collect into l_tab limit l_limit;

    exit when l_tab.count = 0;

    for i_idx in l_tab.first .. l_tab.last
    loop
      pipe row (l_tab(i_idx));
    end loop;

    exit when p_cursor%notfound;
  end loop;

$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.api_pkg.c_debugging >= 1 $then
  dbug.leave;
$end

  return;
end show_cursor;

function translate_error
( p_sqlerrm in varchar2
, p_function in varchar2
)
return varchar2
is
  l_sqlerrm constant varchar2(32767 char) := utl_i18n.unescape_reference(p_sqlerrm);
  l_generic_exception constant varchar2(100 char) := 'ORA' || to_char(data_api_pkg.c_exception) || ': %';
  l_sep constant varchar2(1 char) := data_api_pkg."#";
  l_error_code varchar2(2000 char) := null;
  l_error_message varchar2(2000 char) := null;
begin
$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.api_pkg.c_debugging >= 1 $then
  dbug.enter($$PLSQL_UNIT || '.TRANSLATE_ERROR');
  dbug.print
  ( dbug."input"
  , 'p_function: %s; l_sqlerrm: %s'
  , p_function
  , l_sqlerrm
  );
$end

  if l_sqlerrm like l_generic_exception
  then
    for r in
    ( select  t.column_value as txt
      ,       (rownum-2) as nr
      from    table(oracle_tools.api_pkg.list2collection(p_value_list => l_sqlerrm, p_sep => l_sep, p_ignore_null => 0)) t
    )
    loop
$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.api_pkg.c_debugging >= 1 $then
      dbug.print(dbug."info", 'r.nr: %s; r.txt: %s', r.nr, r.txt);
$end

      case r.nr
        when -1 -- ORA-20001:
        then
          null;

        when 0 -- the error code
        then
          l_error_code := r.txt;

          execute immediate 'begin :1 := ' || oracle_tools.data_api_pkg.dbms_assert$sql_object_name(p_function, 'function') || '(:2); end;' using out l_error_message, in l_error_code;

$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.api_pkg.c_debugging >= 1 $then
          dbug.print(dbug."info", 'l_error_code: %s; l_error_message: %s', l_error_code, l_error_message); 
$end

        else -- param 1, 2, 3, etcetera
          l_error_message := replace(l_error_message, '<p' || r.nr || '>', r.txt);

$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.api_pkg.c_debugging >= 1 $then
          dbug.print(dbug."info", 'l_error_message: %s', l_error_message);
$end

      end case;
    end loop;
$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.api_pkg.c_debugging >= 1 $then
  else
    dbug.print(dbug."info", 'Error does not match: %s', l_generic_exception); 
$end
  end if;

  if l_error_message is not null
  then
    -- GJP 2020-03-02  Preprend the error code to get a better error message
    l_error_message := l_error_code || ': ' || l_error_message;
  else
    l_error_message := l_sqlerrm;
  end if;

$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.api_pkg.c_debugging >= 1 $then
  dbug.print(dbug."output", 'return: %s', nvl(l_error_message, l_sqlerrm));
  dbug.leave;
$end

  return nvl(l_error_message, l_sqlerrm);

$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.api_pkg.c_debugging >= 1 $then
exception
  when others
  then
    dbug.leave_on_error;
    raise;
$end
end translate_error;

function list2collection
( p_value_list in varchar2
, p_sep in varchar2
, p_ignore_null in naturaln
)
return sys.odcivarchar2list
is
  l_collection sys.odcivarchar2list;
  l_max_pos constant integer := 32767; -- or 4000
begin
  if p_sep is null
  then
    raise value_error;
  end if;
  
  select  t.val
  bulk collect
  into    l_collection
  from    ( select  substr(str, pos + 1, lead(pos, 1, l_max_pos) over(order by pos) - pos - 1) val
            from    ( select  str
                      ,       instr(str, p_sep, 1, level) pos
                      from    ( select  p_value_list as str
                                from    dual
                                where   rownum <= 1
                              )
                      connect by
                              level <= length(str) - nvl(length(replace(str, p_sep)), 0) /* number of separators */ + 1
                    )
          ) t
  where   ( p_ignore_null = 0 or t.val is not null );

  return l_collection;
end list2collection;

function collection2list
( p_value_tab in sys.odcivarchar2list
, p_sep in varchar2
, p_ignore_null in naturaln
)
return varchar2
deterministic
is
  l_values_list varchar2(32767 byte) := null;
begin
  if p_sep is null
  then
    raise value_error;
  end if;
  
  /* GJP 2023-03-19 Why slow when it can be more efficient :) */
  /*
  select  listagg(t.column_value, p_sep) within group (order by t.column_value)
  into    l_values_list
  from    table(p_value_tab) t
  where   ( p_ignore_null = 0 or t.column_value is not null );
  */
  if p_value_tab is not null and p_value_tab.count > 0
  then
    for i_idx in p_value_tab.first .. p_value_tab.last
    loop
      if p_ignore_null = 0 or p_value_tab(i_idx) is not null
      then
        if l_values_list is null
        then
          l_values_list := p_value_tab(i_idx);
        else
          l_values_list := l_values_list || p_sep || p_value_tab(i_idx);
        end if;
      end if;
    end loop;
  end if;
  
  return l_values_list;
end collection2list;

function excel_date_number2date
( p_date_number in integer
)
return date
deterministic
is
begin
  /*
  --
  -- Excel gives each date a numeric value starting at 1st January 1900.
  -- 1st January 1900 has a numeric value of 1, the 2nd January 1900 has a numeric value of 2 and so on.
  -- These are called ‘date serial numbers’, and they enable us to do math calculations and use dates in formulas.
  --
  -- Caution! Excel dates after 28th February 1900 are actually one day out. Excel behaves as though the date 29th February 1900 existed, which it didn't.
  */
  return ( to_date('01/01/1900', 'dd/mm/yyyy') - case when p_date_number <= 31 + 28 then 1 else 2 end ) + p_date_number;
end excel_date_number2date;

procedure ut_expect_violation
( p_br_name in varchar2
, p_sqlcode in integer
, p_sqlerrm in varchar2
, p_data_owner in all_tables.owner%type
)
is
begin
$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.api_pkg.c_debugging >= 1 $then
  dbug.enter($$PLSQL_UNIT || '.UT_EXPECT_VIOLATION');
  dbug.print
  ( dbug."input"
  , 'p_br_name: %s; p_sqlcode: %s; p_sqlerrm: %s; p_data_owner: %s'
  , p_br_name
  , p_sqlcode
  , p_sqlerrm
  , p_data_owner
  );
$end

  case
    when p_sqlcode in (data_api_pkg.c_exception, data_api_pkg.c_check_constraint, data_api_pkg.c_unique_constraint, data_api_pkg.c_fk_non_transferable)
    then
      if p_sqlcode = data_api_pkg.c_exception and
         -- ORA-20001: #BR_CFN_5#[08-DEC-14, ]#[08-NOV-14, 08-DEC-14]#2907
         ( substr(p_sqlerrm, instr(p_sqlerrm, ':')+2) = '#' || p_br_name or
           substr(p_sqlerrm, instr(p_sqlerrm, ':')+2) like '#' || p_br_name || '#_%'
         )
      then
        null;
      elsif p_sqlcode in (data_api_pkg.c_check_constraint, data_api_pkg.c_unique_constraint) and
            p_sqlerrm like '%(' || p_data_owner || '.' || p_br_name || ')%'
      then
        null;
      elsif p_sqlcode in (data_api_pkg.c_fk_non_transferable, data_api_pkg.c_cannot_update_to_null) and
            p_sqlerrm like '%' || p_br_name || '%'
      then
        -- RAISE_APPLICATION_ERROR(-20225, 'Non Transferable FK constraint  on table BNS_TPL_OBJECTIVE_PLAN_DETAILS is violated');
        null;
      else
        raise_application_error(-20000, 'The business rule "' || p_br_name || '" is not part of the error "' || p_sqlerrm || '"');
      end if;

    else
      raise_application_error(-20000, 'Unknown sqlcode: ' || p_sqlcode);
  end case;

$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.api_pkg.c_debugging >= 1 $then
  dbug.leave;
exception
  when others
  then
    dbug.leave_on_error;
    raise;
$end
end ut_expect_violation;

procedure dbms_output_enable
( p_db_link in varchar2
, p_buffer_size in integer default null
)
is
begin
$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.api_pkg.c_debugging >= 1 $then
  dbug.enter($$PLSQL_UNIT || '.DBMS_OUTPUT_ENABLE');
  dbug.print(dbug."input", 'p_db_link: %s; p_buffer_size: %s', p_db_link, p_buffer_size);
$end

  -- check SQL injection
  if oracle_tools.data_api_pkg.dbms_assert$simple_sql_name(p_db_link, 'database link') is null
  then
    raise value_error;
  end if;

  execute immediate
    'call ' || oracle_tools.data_api_pkg.dbms_assert$qualified_sql_name('dbms_output.enable@' || p_db_link, 'remote procedure') || '(:b1)'
    using p_buffer_size;

$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.api_pkg.c_debugging >= 1 $then
  dbug.leave;
exception
  when others
  then
    dbug.leave_on_error;
    raise;
$end
end dbms_output_enable;

procedure dbms_output_clear
( p_db_link in varchar2
)
is
begin
$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.api_pkg.c_debugging >= 1 $then
  dbug.enter($$PLSQL_UNIT || '.DBMS_OUTPUT_CLEAR');
  dbug.print(dbug."input", 'p_db_link: %s', p_db_link);
$end

  -- check SQL injection
  if oracle_tools.data_api_pkg.dbms_assert$simple_sql_name(p_db_link, 'database link') is null
  then
    raise value_error;
  end if;

  execute immediate
    utl_lms.format_message
    ( '
declare 
  l_line varchar2(32767 char); 
  l_status integer; 
begin 
  dbms_output.get_line@%s(l_line, l_status);
end;'
    , oracle_tools.data_api_pkg.dbms_assert$simple_sql_name(p_db_link, 'database link')
    );

$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.api_pkg.c_debugging >= 1 $then
  dbug.leave;
exception
  when others
  then
    dbug.leave_on_error;
    raise;
$end
end dbms_output_clear;    

procedure dbms_output_flush
( p_db_link in varchar2
)
is
begin
$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.api_pkg.c_debugging >= 1 $then
  dbug.enter($$PLSQL_UNIT || '.DBMS_OUTPUT_FLUSH');
  dbug.print(dbug."input", 'p_db_link: %s', p_db_link);
$end

  -- check SQL injection
  if oracle_tools.data_api_pkg.dbms_assert$simple_sql_name(p_db_link, 'database link') is null
  then
    raise value_error;
  end if;

  execute immediate
    utl_lms.format_message
    ( '
declare
  l_line varchar2(32767 char);
  l_status integer;
begin
  loop
    dbms_output.get_line@%s(line => l_line, status => l_status);
    exit when l_status != 0;
    dbms_output.put_line(l_line);
  end loop;
end;'
    , oracle_tools.data_api_pkg.dbms_assert$simple_sql_name(p_db_link, 'databse link')
    );

$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.api_pkg.c_debugging >= 1 $then
  dbug.leave;
exception
  when others
  then
    dbug.leave_on_error;
    raise;
$end
end dbms_output_flush;

procedure dsort
( p_graph in out nocopy t_graph
, p_result out nocopy dbms_sql.varchar2_table /* I */
)
is
  l_error_n t_object;
begin
$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.api_pkg.c_debugging >= 1 $then
  dbug.enter($$PLSQL_UNIT || '.DSORT');
$end

  while true
  loop
    PRAGMA INLINE (tsort, 'YES');
    tsort(p_graph, p_result, l_error_n);

    exit when l_error_n is null; -- successful: stop

    if p_graph(l_error_n).count = 0
    then
      raise program_error;
    end if;

    p_graph(l_error_n) := c_object_no_dependencies_tab;

    if p_graph(l_error_n).count != 0
    then
      raise program_error;
    end if;
  end loop;

$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.api_pkg.c_debugging >= 1 $then
  dbug.leave;
exception
  when others
  then
    dbug.leave_on_error;
    raise;
$end
end dsort;

$if cfg_pkg.c_testing $then

procedure ut_setup
( p_autonomous_transaction in boolean
, p_br_package_tab in data_br_pkg.t_br_package_tab
, p_init_procedure in all_procedures.object_name%type
, p_insert_procedure in all_procedures.object_name%type
)
is
begin
$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.api_pkg.c_debugging >= 1 $then
  dbug.enter($$PLSQL_UNIT || '.UT_SETUP');
  dbug.print
  ( dbug."input"
  , 'p_autonomous_transaction: %s; p_br_package_tab.count; p_init_procedure: %s; p_insert_procedure: %s'
  , dbug.cast_to_varchar2(p_autonomous_transaction)
  , p_br_package_tab.count
  , p_init_procedure
  , p_insert_procedure
  );
$end

  if p_init_procedure is not null
  then
    execute immediate 'begin ' || oracle_tools.data_api_pkg.dbms_assert$sql_object_name(p_init_procedure, 'procedure') || '; end;';
  end if;

  case
    when p_autonomous_transaction
    then ut_setup_at(p_br_package_tab, p_insert_procedure);
    else ut_setup(p_br_package_tab, p_insert_procedure);
  end case;

$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.api_pkg.c_debugging >= 1 $then
  dbug.leave;
exception
  when others
  then
    dbug.leave_on_error;
    raise;
$end
end ut_setup;

procedure ut_teardown
( p_autonomous_transaction in boolean
, p_br_package_tab in data_br_pkg.t_br_package_tab
, p_init_procedure in all_procedures.object_name%type
, p_delete_procedure in all_procedures.object_name%type
)
is
begin
$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.api_pkg.c_debugging >= 1 $then
  dbug.enter($$PLSQL_UNIT || '.UT_TEARDOWN');
  dbug.print
  ( dbug."input"
  , 'p_autonomous_transaction: %s; p_br_package_tab: %s; p_init_procedure: %s; p_delete_procedure: %s'
  , dbug.cast_to_varchar2(p_autonomous_transaction)
  , p_br_package_tab.count
  , p_init_procedure
  , p_delete_procedure
  );
$end

  if p_init_procedure is not null
  then
    execute immediate 'begin ' || oracle_tools.data_api_pkg.dbms_assert$sql_object_name(p_init_procedure, 'procedure') || '; end;';
  end if;

  case
    when p_autonomous_transaction
    then ut_teardown_at(p_br_package_tab, p_delete_procedure);
    when called_by_utplsql
    then null; -- a rollback to savepoint will be executed by UTPLSQL
    else ut_teardown(p_br_package_tab, p_delete_procedure);
  end case;

$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.api_pkg.c_debugging >= 1 $then
  dbug.leave;
exception
  when others
  then
    dbug.leave_on_error;
    raise;
$end
end ut_teardown;

-- UNIT TEST

procedure ut_excel_date_number2date
is
begin
  -- 1 is 01/01/1900
  ut.expect(excel_date_number2date(1)).to_equal(to_date('01/01/1900', 'dd/mm/yyyy'));
  -- 31 jan 1990
  ut.expect(excel_date_number2date(31)).to_equal(to_date('31/01/1900', 'dd/mm/yyyy'));
  -- 28 feb 1990
  ut.expect(excel_date_number2date(31+28)).to_equal(to_date('28/02/1900', 'dd/mm/yyyy'));
  -- 29 february 1990 exists according to Excel but not for Oracle
  ut.expect(excel_date_number2date(31+29)).to_equal(to_date('28/02/1900', 'dd/mm/yyyy'));
  -- 1 mar 1990
  ut.expect(excel_date_number2date(31+30)).to_equal(to_date('01/03/1900', 'dd/mm/yyyy'));
  ut.expect(excel_date_number2date(44123)).to_equal(to_date('19/10/2020', 'dd/mm/yyyy'));
  ut.expect(excel_date_number2date(44124)).to_equal(to_date('20/10/2020', 'dd/mm/yyyy'));
  ut.expect(excel_date_number2date(44125)).to_equal(to_date('21/10/2020', 'dd/mm/yyyy'));
end ut_excel_date_number2date;

procedure ut_dsort
is
  l_graph t_graph;
  l_result dbms_sql.varchar2_table;
  l_idx pls_integer;

  l_program constant varchar2(100) := $$PLSQL_UNIT || '.UT_SORT_OBJECTS_BY_DEPS';
begin
  l_graph('1')('2') := 1;
  l_graph('1')('3') := 1;
  l_graph('1')('4') := 1;
  l_graph('2')('1') := 1;
  l_graph('2')('3') := 1;
  l_graph('2')('4') := 1;
  l_graph('3')('1') := 1;
  l_graph('3')('2') := 1;
  l_graph('3')('4') := 1;
  l_graph('4')('1') := 1;
  l_graph('4')('2') := 1;
  l_graph('4')('3') := 1;

  dsort
  ( l_graph
  , l_result
  );

  ut.expect(l_result.count, l_program || '#0#count').to_equal(4);
  l_idx := l_result.first;
  while l_idx is not null
  loop
    ut.expect(l_result(l_idx), l_program || '#0#' || to_char(1 + l_idx - l_result.first)).to_equal(to_char(1 + l_result.last - l_idx));      
    l_idx := l_result.next(l_idx);
  end loop;
end ut_dsort;  

$end -- $if cfg_pkg.c_testing $then

end API_PKG;
/

