CREATE OR REPLACE PACKAGE BODY "MSG_SCHEDULER_PKG" AS

subtype job_name_t is user_scheduler_jobs.job_name%type;

"yyyymmddhh24miss" constant varchar2(16) := 'yyyymmddhh24miss';
"yyyy-mm-dd hh24:mi:ss" constant varchar2(21) := 'yyyy-mm-dd hh24:mi:ss';

-- let the launcher program (that is used for job names too) start with LAUNCHER so a wildcard search for worker group jobs does not return the launcher job
c_program_launcher constant user_scheduler_programs.program_name%type := 'LAUNCHER_PROCESSING';
c_program_worker_group constant user_scheduler_programs.program_name%type := 'PROCESSING';

c_schedule_launcher constant user_scheduler_programs.program_name%type := 'LAUNCHER_SCHEDULE';

c_session_id constant user_scheduler_running_jobs.session_id%type := to_number(sys_context('USERENV', 'SID'));

-- ORA-27476: "MSG_AQ_PKG$PROCESSING_LAUNCHER#1" does not exist
e_job_does_not_exist exception;
pragma exception_init(e_job_does_not_exist, -27476);

-- sqlerrm: ORA-27475: unknown job "BC_API"."MSG_AQ_PKG$PROCESSING_LAUNCHER#1"
e_job_unknown exception;
pragma exception_init(e_job_unknown, -27475);

$if oracle_tools.cfg_pkg.c_debugging $then
 
subtype t_dbug_channel_tab is msg_pkg.t_boolean_lookup_tab;

g_dbug_channel_tab t_dbug_channel_tab;

$end -- $if oracle_tools.cfg_pkg.c_debugging $then

procedure init
is
$if oracle_tools.cfg_pkg.c_debugging $then
  l_dbug_channel_active_tab constant sys.odcivarchar2list := msg_constants_pkg.c_dbug_channel_active_tab;
  l_dbug_channel_inactive_tab constant sys.odcivarchar2list := msg_constants_pkg.c_dbug_channel_inactive_tab;
$end    
begin
$if oracle_tools.cfg_pkg.c_debugging $then
  for i_idx in l_dbug_channel_active_tab.first .. l_dbug_channel_active_tab.last
  loop
    g_dbug_channel_tab(l_dbug_channel_active_tab(i_idx)) := dbug.active(l_dbug_channel_active_tab(i_idx));

    dbug.activate
    ( l_dbug_channel_active_tab(i_idx)
    , true
    );
  end loop;

  for i_idx in l_dbug_channel_inactive_tab.first .. l_dbug_channel_inactive_tab.last
  loop
    g_dbug_channel_tab(l_dbug_channel_inactive_tab(i_idx)) := dbug.active(l_dbug_channel_inactive_tab(i_idx));

    dbug.activate
    ( l_dbug_channel_inactive_tab(i_idx)
    , false
    );
  end loop;
$end

  msg_pkg.init;
end init;

$if oracle_tools.cfg_pkg.c_debugging $then

procedure profiler_report
is
  l_dbug_channel all_objects.object_name%type := g_dbug_channel_tab.first;
begin
  dbug.enter($$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.' || 'PROFILER_REPORT');

  for r in
  ( select  t.module_name
    ,       t.nr_calls
    ,       t.elapsed_time
    ,       t.avg_time
    from    table(dbug_profiler.show) t
  )
  loop
    dbug.print
    ( dbug."info"
    , 'module: %s; # calls: %s, elapsed time: %s; avg_time: %s'
    , r.module_name
    , r.nr_calls
    , r.elapsed_time
    , r.avg_time
    );
  end loop;

  dbug.leave;
exception
  when others
  then
    dbug.leave_on_error;
    null; -- do not re-raise
end profiler_report;

$end -- $if oracle_tools.cfg_pkg.c_debugging $then

procedure done
is
$if oracle_tools.cfg_pkg.c_debugging $then
  l_dbug_channel all_objects.object_name%type := g_dbug_channel_tab.first;
$end  
begin
$if oracle_tools.cfg_pkg.c_debugging $then
/* GJP 2023-03-13 Getting dbug errors. */
/*
  if dbug.active('PROFILER')
  then
    profiler_report;
  end if;
*/  
$end  

  msg_pkg.done;

$if oracle_tools.cfg_pkg.c_debugging $then
/* GJP 2023-03-13 Do not change dbug settings anymore. */
/*
  while l_dbug_channel is not null
  loop
    dbug.activate(l_dbug_channel, g_dbug_channel_tab(l_dbug_channel));
    
    l_dbug_channel := g_dbug_channel_tab.next(l_dbug_channel);
  end loop;
*/  
$end -- $if oracle_tools.cfg_pkg.c_debugging $then  
end done;

function join_job_name
( p_processing_package in varchar2
, p_program_name in varchar2
, p_worker_nr in positive default null
)
return job_name_t
is
  l_job_name job_name_t;
begin
  l_job_name :=
    p_processing_package ||
    '$' ||
    p_program_name ||
    case when p_worker_nr is not null then '#' || to_char(p_worker_nr) end;

$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.print(dbug."info", 'join_job_name: %s', l_job_name);
$end

  return l_job_name;
end join_job_name;

procedure split_job_name
( p_job_name in job_name_t
, p_processing_package out nocopy varchar2
, p_program_name out nocopy varchar2
, p_worker_nr out nocopy positive
)
is
  l_pos$ pls_integer;
  l_pos# pls_integer;
begin
  p_processing_package := null;
  p_program_name := null;
  p_worker_nr := null;
  
  l_pos$ := instr(p_job_name, '$'); -- first $
  if l_pos$ > 0
  then
    p_processing_package := substr(p_job_name, 1, l_pos$ - 1);
    p_program_name := substr(p_job_name, l_pos$ + 1); -- rest of the job name
    
    l_pos# := instr(p_program_name, '#'); -- first #
    case
      when l_pos# is null -- p_program_name is null
      then
        null;
        
      when l_pos# = 0
      then
        null;
        
      when l_pos# > 0
      then
        p_worker_nr := to_number(substr(p_program_name, l_pos# + 1));
        p_program_name := substr(p_program_name, 1, l_pos# - 1);
    end case;
  end if;

$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.print
  ( dbug."info"
  , q'[split_job_name(p_job_name => '%s', p_processing_package => '%s', p_program_name => '%s', p_worker_nr => %s)]'
  , p_job_name
  , p_processing_package
  , p_program_name
  , p_worker_nr
  );
$end  

end split_job_name;

function to_like_expr
( p_expr in varchar2
)
return varchar2
is
  l_expr constant varchar2(4000 char) := replace(replace(p_expr, '_', '\_'), '\\_', '\_');
begin
$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.print
  ( dbug."info"
  , q'[to_like_expr(p_expr => '%s') = '%s')]'
  , p_expr
  , l_expr
  );
$end  

  return l_expr;
end to_like_expr;

function get_jobs
( p_job_name_expr in varchar2
, p_state in user_scheduler_jobs.state%type default null
, p_only_workers in integer default null -- 0: only launchers; 1: only workers; null: any
)
return sys.odcivarchar2list
is
  l_job_names sys.odcivarchar2list;
  l_job_name_expr constant job_name_t := to_like_expr(p_job_name_expr);
begin
  select  j.job_name
  bulk collect
  into    l_job_names
  from    user_scheduler_jobs j
  where   j.job_name like l_job_name_expr escape '\'
  and     ( p_state is null or j.state = p_state )
  and     ( p_only_workers is null or p_only_workers = sign(instr(j.job_name, '#')) )
  order by
          job_name -- permanent launcher first, then its workers jobs, next temporary launchers and their workers
  ;
  return l_job_names;
end get_jobs;

function does_job_exist
( p_job_name in job_name_t
)
return boolean
is
begin
  PRAGMA INLINE (get_jobs, 'YES');
  return get_jobs(p_job_name).count = 1;
end does_job_exist;

function is_job_running
( p_job_name in job_name_t
)
return boolean
is
begin
  PRAGMA INLINE (get_jobs, 'YES');
  return get_jobs(p_job_name, 'RUNNING').count = 1;
end is_job_running;

function does_program_exist
( p_program_name in varchar2
)
return boolean
is
  l_found pls_integer;
begin
  select  1
  into    l_found
  from    user_scheduler_programs p
  where   p.program_name = p_program_name;

  return true;
exception
  when no_data_found
  then
    return false;
end does_program_exist;

function does_schedule_exist
( p_schedule_name in varchar2
)
return boolean
is
  l_found pls_integer;
begin
  select  1
  into    l_found
  from    user_scheduler_schedules p
  where   p.schedule_name = p_schedule_name;

  return true;
exception
  when no_data_found
  then
    return false;
end does_schedule_exist;

function session_job_name
( p_session_id in varchar2 default c_session_id
)
return job_name_t
is
  l_job_name job_name_t;
begin
$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.enter($$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.SESSION_JOB_NAME');
  dbug.print(dbug."input", 'p_session_id: %s', p_session_id);
$end

  -- Is this session running as a job?
  -- If not, just create a job name launcher to be used by the worker jobs.
  begin
    select  j.job_name
    into    l_job_name
    from    user_scheduler_running_jobs j
    where   j.session_id = p_session_id;
  exception
    when no_data_found
    then
      l_job_name := null;
  end;

$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.print(dbug."output", 'return: %s', l_job_name);
  dbug.leave;
$end

  return l_job_name;
end session_job_name;

procedure create_program
( p_program_name in varchar2
)
is
  l_program_name constant all_objects.object_name%type := upper(p_program_name);
begin
$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.enter($$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.CREATE_PROGRAM');
  dbug.print
  ( dbug."input"
  , 'p_program_name: %s'
  , p_program_name
  );
$end

  case l_program_name
    when c_program_launcher
    then
      dbms_scheduler.create_program
      ( program_name => l_program_name
      , program_type => 'STORED_PROCEDURE'
      , program_action => $$PLSQL_UNIT || '.' || p_program_name -- program name is the same as module name
      , number_of_arguments => 3
      , enabled => false
      , comments => 'Main program for processing messages by spawning worker jobs.'
      );

      for i_par_idx in 1..3
      loop
        dbms_scheduler.define_program_argument
        ( program_name => l_program_name
        , argument_name => case i_par_idx
                             when 1 then 'P_PROCESSING_PACKAGE'
                             when 2 then 'P_NR_WORKERS_EACH_GROUP'
                             when 3 then 'P_NR_WORKERS_EXACT'
                           end
        , argument_position => i_par_idx
        , argument_type => case 
                             when i_par_idx = 1
                             then 'VARCHAR2'
                             else 'NUMBER'
                           end
        , default_value => case i_par_idx
                             when 2 then to_char(msg_constants_pkg.c_nr_workers_each_group)
                             when 3 then to_char(msg_constants_pkg.c_nr_workers_exact)
                             else null
                           end
        );
      end loop;

    when c_program_worker_group
    then
      dbms_scheduler.create_program
      ( program_name => l_program_name
      , program_type => 'STORED_PROCEDURE'
      , program_action => $$PLSQL_UNIT || '.' || p_program_name -- program name is the same as module name
      , number_of_arguments => 5
      , enabled => false
      , comments => 'Worker program for processing messages supervised by the main job.'
      );
  
      for i_par_idx in 1..5
      loop
        dbms_scheduler.define_program_argument
        ( program_name => l_program_name
        , argument_name => case i_par_idx
                             when 1 then 'P_PROCESSING_PACKAGE'
                             when 2 then 'P_GROUPS_TO_PROCESS_LIST'
                             when 3 then 'P_NR_WORKERS'
                             when 4 then 'P_WORKER_NR'
                             when 5 then 'P_END_DATE'
                           end
        , argument_position => i_par_idx
        , argument_type => -- informational only
                           case 
                             when i_par_idx <= 2
                             then 'VARCHAR2'
                             when i_par_idx <= 4
                             then 'NUMBER'
                             else 'VARCHAR2'
                           end
        , default_value => null
        );
      end loop;
  end case;
      
  dbms_scheduler.enable(name => l_program_name);

$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.leave;
$end
end create_program;

procedure submit_processing
( p_processing_package in varchar2
, p_groups_to_process_list in varchar2
, p_nr_workers in positiven
, p_worker_nr in positive
, p_end_date in user_scheduler_jobs.end_date%type
)
is
  l_job_name constant job_name_t := join_job_name(p_processing_package, c_program_worker_group, p_worker_nr);
  l_argument_value user_scheduler_program_args.default_value%type;
begin  
$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.enter($$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.SUBMIT_PROCESSING');
  dbug.print
  ( dbug."input"
  , 'p_processing_package: %s; p_groups_to_process_list: %s; p_nr_workers: %s; p_worker_nr: %s; p_end_date: %s'
  , p_processing_package
  , p_groups_to_process_list
  , p_nr_workers
  , p_worker_nr
  , to_char(p_end_date, "yyyy-mm-dd hh24:mi:ss")
  );
$end

  PRAGMA INLINE (is_job_running, 'YES');
  if is_job_running(l_job_name)
  then
    raise_application_error
    ( c_job_already_running
    , utl_lms.format_message
      ( c_job_already_running_msg
      , l_job_name
      )
    );
  end if;
  
  PRAGMA INLINE (does_job_exist, 'YES');
  if not(does_job_exist(l_job_name))
  then  
    if not(does_program_exist(c_program_worker_group))
    then
      create_program(c_program_worker_group);
    end if;

    -- use inline schedule
    dbms_scheduler.create_job
    ( job_name => l_job_name
    , program_name => c_program_worker_group
    , start_date => null
      -- will never repeat
    , repeat_interval => null
    , end_date => p_end_date
    , job_class => msg_constants_pkg.c_job_class_worker
    , enabled => false -- so we can set job arguments
    , auto_drop => true -- one-off jobs
    , comments => 'Worker job for processing messages.'
    , job_style => msg_constants_pkg.c_job_style_worker
    , credential_name => null
    , destination_name => null
    );
  else
    dbms_scheduler.disable(l_job_name);    
  end if;
  
  -- set the actual arguments

  for r in
  ( select  a.argument_name
    from    user_scheduler_jobs j
            inner join user_scheduler_program_args a
            on a.program_name = j.program_name
    where   j.job_name = l_job_name
    order by
            a.argument_position
  )
  loop
$if oracle_tools.cfg_pkg.c_debugging $then
    dbug.print(dbug."info", 'argument name: %s', r.argument_name);
$end

    case r.argument_name
      when 'P_PROCESSING_PACKAGE'
      then l_argument_value := p_processing_package;
      when 'P_GROUPS_TO_PROCESS_LIST'
      then l_argument_value := p_groups_to_process_list;
      when 'P_NR_WORKERS'
      then l_argument_value := to_char(p_nr_workers);
      when 'P_WORKER_NR'
      then l_argument_value := to_char(p_worker_nr);
      when 'P_END_DATE'
      then l_argument_value := msg_pkg.timestamp_tz2timestamp_tz_str(p_end_date);
    end case;

$if oracle_tools.cfg_pkg.c_debugging $then
    dbug.print(dbug."info", 'argument value: %s', l_argument_value);
$end

    dbms_scheduler.set_job_argument_value
    ( job_name => l_job_name
    , argument_name => r.argument_name
    , argument_value => l_argument_value
    );
  end loop;
  
  dbms_scheduler.enable(l_job_name);

$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.leave;
$end
end submit_processing;

function determine_processing_package
( p_processing_package in varchar2
)
return varchar2
is
begin
  if p_processing_package is not null
  then
    return msg_pkg.get_object_name(p_object_name => p_processing_package, p_what => 'package', p_fq => 0, p_qq => 0);
  else
    raise program_error;
  end if;
end determine_processing_package;

procedure stop_job
( p_job_name in job_name_t
)
is
begin
$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.enter($$PLSQL_UNIT || '.STOP_JOB');
  dbug.print(dbug."input", 'p_job_name: %s', p_job_name);
$end

  for i_step in 1..2
  loop
$if oracle_tools.cfg_pkg.c_debugging $then
    dbug.print(dbug."info", 'i_step: %s', i_step);
$end

    -- stop and disable jobs gracefully first
    PRAGMA INLINE (is_job_running, 'YES');
    exit when not(is_job_running(p_job_name));

    dbms_scheduler.stop_job(job_name => p_job_name, force => case i_step when 1 then false else true end);
  end loop;

$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.leave;
exception
  when others
  then
    dbug.leave_on_error;
    raise;
$end    
end stop_job;

procedure drop_job
( p_job_name in job_name_t
)
is
begin
$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.enter($$PLSQL_UNIT || '.DROP_JOB');
  dbug.print(dbug."input", 'p_job_name: %s', p_job_name);
$end

  PRAGMA INLINE (stop_job, 'YES');
  stop_job(p_job_name);
  dbms_scheduler.drop_job(job_name => p_job_name, force => false);

$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.leave;
$end
exception
  when e_job_unknown -- when the job is stopped it may disappear due to auto_drop true
  then
$if oracle_tools.cfg_pkg.c_debugging $then
    dbug.leave;
$end
    null;

$if oracle_tools.cfg_pkg.c_debugging $then
  when others
  then
    dbug.leave_on_error;
    raise;
$end    
end drop_job;

procedure processing
( p_processing_package in varchar2 
, p_groups_to_process_list in varchar2
, p_nr_workers in positiven
, p_worker_nr in positive
, p_end_date in varchar2
)
is
  l_processing_package constant all_objects.object_name%type := determine_processing_package(p_processing_package);
  l_job_name constant job_name_t := session_job_name();
  l_statement varchar2(32767 byte);
  l_groups_to_process_tab sys.odcivarchar2list;
  l_inactive_worker_tab sys.odcinumberlist; -- for supervisor only
  l_end_date constant msg_pkg.timestamp_tz_t := msg_pkg.timestamp_tz_str2timestamp_tz(p_end_date);

  -- ORA-06550: line 1, column 18:
  -- PLS-00302: component 'PROCESING' must be declared
  e_compilation_error exception;
  pragma exception_init(e_compilation_error, -6550);

  procedure restart_workers
  is
    l_worker_nr positive;
  begin
$if oracle_tools.cfg_pkg.c_debugging $then
    dbug.enter($$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.PROCESSING.RESTART_WORKERS');
$end

    for i_worker_idx in l_inactive_worker_tab.first .. l_inactive_worker_tab.last
    loop
      l_worker_nr := l_inactive_worker_tab(i_worker_idx);
      if l_worker_nr is not null
      then
$if oracle_tools.cfg_pkg.c_debugging $then
        dbug.print
        ( dbug."info"
        , 'Worker %s is inactive'
        , l_worker_nr
        );
$end

        submit_processing
        ( p_processing_package => p_processing_package
        , p_groups_to_process_list => p_groups_to_process_list
        , p_nr_workers => p_nr_workers
        , p_worker_nr => l_worker_nr
        , p_end_date => l_end_date -- all jobs in the worker group are supposed to have the same end date
        );
      end if;
    end loop;
$if oracle_tools.cfg_pkg.c_debugging $then
    dbug.leave;
$end  
  end restart_workers;

  procedure cleanup
  is
  begin
    done;
  end cleanup;
begin
  init;

$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.enter($$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.PROCESSING');
  dbug.print
  ( dbug."input"
  , 'p_processing_package: %s; p_groups_to_process_list: %s; p_nr_workers: %s; p_worker_nr: %s; p_end_date: %s'
  , p_processing_package
  , p_groups_to_process_list
  , p_nr_workers
  , p_worker_nr
  , to_char(l_end_date, "yyyy-mm-dd hh24:mi:ss")
  );
$end

  if l_job_name is null
  then
    raise_application_error
    ( c_session_not_running_job
    , utl_lms.format_message
      ( c_session_not_running_job_msg
      , to_char(c_session_id)
      )
    );
  else
    select  pg.column_value
    bulk collect
    into    l_groups_to_process_tab
    from    table(oracle_tools.api_pkg.list2collection(p_value_list => p_groups_to_process_list, p_sep => ',', p_ignore_null => 1)) pg;

    <<processing_loop>>
    loop
      l_statement := utl_lms.format_message
                     ( q'[
call %s.processing( p_controlling_package => :1
                  , p_groups_to_process_tab => :2
                  , p_nr_workers => :3
                  , p_worker_nr => :4
                  , p_end_date => :5
                  , p_inactive_worker_tab => :6
                  )]'
                     , l_processing_package -- already checked by determine_processing_package
                     );

      begin
        execute immediate l_statement
          using in $$PLSQL_UNIT, in l_groups_to_process_tab, in p_nr_workers, in p_worker_nr, in l_end_date, out l_inactive_worker_tab;

        if p_worker_nr is null and l_inactive_worker_tab is not null and l_inactive_worker_tab.count > 0
        then
          restart_workers;
        else
          exit processing_loop; -- the processing just succeeded (no signal), so stop
        end if;
      exception
        when e_compilation_error
        then
$if oracle_tools.cfg_pkg.c_debugging $then
          dbug.print(dbug."error", 'statement: %s', l_statement);
          dbug.on_error;
$end                  
          raise;

        when others
        then
$if oracle_tools.cfg_pkg.c_debugging $then
          dbug.on_error;
$end
          raise;
      end;
    end loop processing_loop;
  end if;

$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.leave;
$end  

  cleanup;
exception
  when others
  then
$if oracle_tools.cfg_pkg.c_debugging $then  
    dbug.leave_on_error;
$end    
    cleanup;
    raise;
end processing;

-- PUBLIC

procedure do
( p_command in varchar2
, p_processing_package in varchar2
)
is
  pragma autonomous_transaction;

  l_command_tab constant sys.odcivarchar2list :=
    case lower(p_command)
      when 'start'
      then sys.odcivarchar2list('check_jobs_not_running', p_command)
      when 'stop'
      then sys.odcivarchar2list(p_command, 'check_jobs_not_running')
      when 'restart'
      then sys.odcivarchar2list('stop', 'check_jobs_not_running', 'start')
      when 'drop'
      then sys.odcivarchar2list('stop', 'check_jobs_not_running', 'drop')
      else sys.odcivarchar2list(p_command)
    end;    
  l_processing_package all_objects.object_name%type := trim('"' from to_like_expr(upper(p_processing_package)));
  l_processing_package_tab sys.odcivarchar2list;
  l_job_name_launcher job_name_t;
  l_job_name_prefix job_name_t;
  l_job_names sys.odcivarchar2list;

  -- for split job name
  l_processing_package_dummy all_objects.object_name%type;
  l_program_name_dummy user_scheduler_programs.program_name%type;
  l_worker_nr positive;
begin
$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.enter($$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.DO');
  dbug.print(dbug."input", 'p_command: %s; p_processing_package: %s', p_command, p_processing_package);
$end

  select  p.package_name
  bulk collect
  into    l_processing_package_tab
  from    user_arguments p
  where   p.object_name = 'GET_GROUPS_TO_PROCESS'
  and     ( l_processing_package is null or p.package_name like l_processing_package escape '\' )
  intersect
  select  p.package_name
  from    user_arguments p
  where   p.object_name = 'PROCESSING'
  and     ( l_processing_package is null or p.package_name like l_processing_package escape '\' )
  ;

  if l_processing_package_tab.count = 0
  then
    raise no_data_found;
  end if;

  <<processing_package_loop>>
  for i_package_idx in l_processing_package_tab.first .. l_processing_package_tab.last
  loop
    l_processing_package := l_processing_package_tab(i_package_idx);

$if oracle_tools.cfg_pkg.c_debugging $then
    dbug.print(dbug."info", 'l_processing_package_tab(%s): %s', i_package_idx, l_processing_package_tab(i_package_idx));
$end

    l_job_name_launcher :=
      join_job_name
      ( p_processing_package => l_processing_package
      , p_program_name => c_program_launcher
      );
    l_job_name_prefix :=
      join_job_name
      ( p_processing_package => l_processing_package 
      , p_program_name => c_program_worker_group
      , p_worker_nr => null
      );

    <<command_loop>>
    for i_command_idx in l_command_tab.first .. l_command_tab.last
    loop
$if oracle_tools.cfg_pkg.c_debugging $then
      dbug.print(dbug."info", 'l_command_tab(%s): %s', i_command_idx, l_command_tab(i_command_idx));
$end

      if l_command_tab(i_command_idx) in ('start', 'stop')
      then
        execute immediate utl_lms.format_message('call %s.do(:1, :2)', l_processing_package)
          using in l_command_tab(i_command_idx), in $$PLSQL_UNIT;
      end if;

      case l_command_tab(i_command_idx)
        when 'check_jobs_not_running'
        then
          PRAGMA INLINE (get_jobs, 'YES');
          l_job_names := get_jobs(l_job_name_prefix || '%', 'RUNNING');
          if l_job_names.count > 0
          then
            raise_application_error
            ( c_there_are_running_jobs
            , utl_lms.format_message
              ( c_there_are_running_jobs_msg
              , l_job_name_prefix || '%'
              , chr(10) || oracle_tools.api_pkg.collection2list(p_value_tab => l_job_names, p_sep => chr(10), p_ignore_null => 1)
              )
            );
          end if;
          
        when 'start'
        then
          begin
            -- respect the fact that the job is there with its current job arguments (maybe a DBA did that)
            dbms_scheduler.disable(l_job_name_launcher);
            dbms_scheduler.enable(l_job_name_launcher);
          exception
            when others
            then
$if oracle_tools.cfg_pkg.c_debugging $then
              dbug.on_error;
$end
              submit_launcher_processing(p_processing_package => l_processing_package);
          end;

          -- But since the next run may take some time, we must schedule the jobs till then.
          -- Job is running or scheduled, but we may have to run workers between now and the next run date
          begin
            launcher_processing(p_processing_package => l_processing_package);
          exception
            when e_no_groups_to_process
            then null;
          end;

        when 'stop'
        then
          PRAGMA INLINE (get_jobs, 'YES');
          l_job_names := get_jobs( p_job_name_expr => l_job_name_prefix || '%');
          if l_job_names.count > 0
          then
            <<job_loop>>
            for i_job_idx in l_job_names.first .. l_job_names.last
            loop
              PRAGMA INLINE (split_job_name, 'YES');
              split_job_name
              ( p_job_name => l_job_names(i_job_idx)
              , p_processing_package => l_processing_package_dummy
              , p_program_name => l_program_name_dummy
              , p_worker_nr => l_worker_nr
              );

$if oracle_tools.cfg_pkg.c_debugging $then
              dbug.print
              ( dbug."info"
              , 'trying to drop %s job %s'
              , case when l_worker_nr is null then 'supervisor' else 'worker' end
              , l_job_names(i_job_idx)
              );
$end

              -- kill
              begin                  
                -- drop worker jobs
                PRAGMA INLINE (drop_job, 'YES');
                drop_job(l_job_names(i_job_idx));
              exception
                when e_job_does_not_exist
                then null;
                
                when others
                then
$if oracle_tools.cfg_pkg.c_debugging $then
                  dbug.on_error;
$end
                  null;
              end;
            end loop job_loop;
          end if;

        when 'drop'
        then
          <<force_loop>>
          for i_force in 0..1 -- 0: force false
          loop
            PRAGMA INLINE (get_jobs, 'YES');
            l_job_names := get_jobs(p_job_name_expr => l_job_name_prefix || '%');

            if l_job_names.count > 0
            then
              <<job_loop>>
              for i_job_idx in l_job_names.first .. l_job_names.last
              loop
$if oracle_tools.cfg_pkg.c_debugging $then
                dbug.print
                ( dbug."info"
                , 'trying to drop job %s'
                , l_job_names(i_job_idx)
                );
$end

                begin
                  PRAGMA INLINE (drop_job, 'YES');
                  drop_job(l_job_names(i_job_idx));
                exception
                  when others
                  then
$if oracle_tools.cfg_pkg.c_debugging $then
                    dbug.on_error;
$end
                    null;
                end;
              end loop job_loop;
            end if;
          end loop force_loop;

        else
          raise_application_error
          ( c_unexpected_command
          , utl_lms.format_message
            ( c_unexpected_command_msg
            , l_command_tab(i_command_idx)
            )
          );

      end case;
    end loop command_loop;
  end loop processing_package_loop;

  commit;

$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.leave;
$end
end do;

procedure submit_launcher_processing
( p_processing_package in varchar2
, p_nr_workers_each_group in positive
, p_nr_workers_exact in positive
, p_repeat_interval in varchar2
)
is
  l_processing_package constant all_objects.object_name%type := determine_processing_package(p_processing_package);
  l_job_name_launcher job_name_t;
  l_argument_value user_scheduler_program_args.default_value%type;
begin
$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.enter($$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.SUBMIT_LAUNCHER_PROCESSING');
  dbug.print
  ( dbug."input"
  , 'p_processing_package: %s; p_nr_workers_each_group: %s; p_nr_workers_exact: %s; p_repeat_interval: %s'
  , p_processing_package
  , p_nr_workers_each_group
  , p_nr_workers_exact
  , p_repeat_interval
  );
$end

  l_job_name_launcher :=
    join_job_name
    ( p_processing_package => l_processing_package
    , p_program_name => c_program_launcher
    );

  PRAGMA INLINE (is_job_running, 'YES');
  if is_job_running(l_job_name_launcher)
  then
    raise too_many_rows;
  end if;

  PRAGMA INLINE (does_job_exist, 'YES');
  if not(does_job_exist(l_job_name_launcher))
  then
    if not(does_program_exist(c_program_launcher))
    then
      create_program(c_program_launcher);
    end if;

    if p_repeat_interval is null
    then
      raise program_error;
    else
      -- a repeating job
      if not(does_schedule_exist(c_schedule_launcher))
      then
        dbms_scheduler.create_schedule
        ( schedule_name => c_schedule_launcher
        , start_date => null
        , repeat_interval => p_repeat_interval
        , end_date => null
        , comments => 'Launcher job schedule'
        );
      end if;

      dbms_scheduler.create_job
      ( job_name => l_job_name_launcher
      , program_name => c_program_launcher
      , schedule_name => c_schedule_launcher
      , job_class => 'DEFAULT_JOB_CLASS'
      , enabled => false -- so we can set job arguments
      , auto_drop => false
      , comments => 'Repeating job for processing messages.'
      , job_style => 'REGULAR'
      , credential_name => null
      , destination_name => null
      );
    end if;
  else
    dbms_scheduler.disable(l_job_name_launcher); -- stop the job so we can give it job arguments
  end if;

  -- set arguments
  for r in
  ( select  a.argument_name
    from    user_scheduler_jobs j
            inner join user_scheduler_program_args a
            on a.program_name = j.program_name
    where   job_name = l_job_name_launcher
    order by
            a.argument_position 
  )
  loop
    case r.argument_name
      when 'P_PROCESSING_PACKAGE'
      then l_argument_value := p_processing_package;
      when 'P_NR_WORKERS_EACH_GROUP'
      then l_argument_value := to_char(p_nr_workers_each_group);
      when 'P_NR_WORKERS_EXACT'
      then l_argument_value := to_char(p_nr_workers_exact);
    end case;

$if oracle_tools.cfg_pkg.c_debugging $then
    dbug.print
    ( dbug."info"
    , 'argument name: %s; argument value: %s'
    , r.argument_name
    , l_argument_value
    );
$end

    dbms_scheduler.set_job_argument_value
    ( job_name => l_job_name_launcher
    , argument_name => r.argument_name
    , argument_value => l_argument_value
    );
  end loop;

  -- start the job
  dbms_scheduler.enable(l_job_name_launcher); 

$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.leave;
$end
end submit_launcher_processing;

procedure launcher_processing
( p_processing_package in varchar2
, p_nr_workers_each_group in positive
, p_nr_workers_exact in positive
)
is
  l_processing_package constant all_objects.object_name%type := determine_processing_package(p_processing_package);
  l_job_name_launcher job_name_t := null;
  l_end_date user_scheduler_jobs.end_date%type := null;
  l_job_name_tab sys.odcivarchar2list := sys.odcivarchar2list();
  l_groups_to_process_tab sys.odcivarchar2list;
  l_groups_to_process_list varchar2(4000 char);
  l_start constant oracle_tools.api_time_pkg.time_t := oracle_tools.api_time_pkg.get_time;
  l_elapsed_time oracle_tools.api_time_pkg.seconds_t;

  procedure check_input_and_state
  is
    l_statement varchar2(32767 byte);
    l_state user_scheduler_jobs.state%type;
  begin
    case
      when ( p_nr_workers_each_group is not null and p_nr_workers_exact is null ) or
           ( p_nr_workers_each_group is null and p_nr_workers_exact is not null )
      then null; -- ok
      else
        raise_application_error
        ( c_one_parameter_not_null
        , utl_lms.format_message
          ( c_one_parameter_not_null_msg
          , p_nr_workers_each_group -- since the type is positive, %d should work
          , p_nr_workers_exact -- idem
          )
        );
    end case;

    -- Is this session running as a job?
    -- If not, just create a job name launcher to be used by the worker jobs.
    
    l_job_name_launcher := session_job_name();
    
    if l_job_name_launcher is null
    then
$if oracle_tools.cfg_pkg.c_debugging $then
      dbug.print
      ( dbug."warning"
      , utl_lms.format_message
        ( 'This session (SID=%s) does not appear to be a running job (for this user), see also column SESSION_ID from view USER_SCHEDULER_RUNNING_JOBS.'
        , to_char(c_session_id)
        )
      );
$end
        
      l_job_name_launcher := 
        join_job_name
        ( p_processing_package => l_processing_package
        , p_program_name => c_program_launcher
        );
    elsif l_job_name_launcher <>
          join_job_name
          ( p_processing_package => l_processing_package
          , p_program_name => c_program_launcher
          )
    then
      raise value_error;
    end if;

    /* the job name launcher must have been scheduled, so we determine the time till the next run (minus some delay) */
    select  j.state
    ,       j.next_run_date - numtodsinterval(msg_constants_pkg.c_time_between_runs, 'SECOND') as end_date
    into    l_state
    ,       l_end_date
    from    user_scheduler_jobs j
    where   j.job_name = l_job_name_launcher;
    
    if l_state in ('SCHEDULED', 'RUNNING', 'DISABLED')
    then
      null; -- OK
    else
      raise_application_error
      ( c_unexpected_job_state
      , utl_lms.format_message
        ( c_unexpected_job_state_msg
        , l_job_name_launcher
        , l_state
        )
      );
    end if;

    l_statement := utl_lms.format_message
                   ( q'[begin :1 := %s.get_groups_to_process(:2); end;]'
                   , l_processing_package -- already checked by determine_processing_package
                   );

    begin
      execute immediate l_statement
        using out l_groups_to_process_tab, in utl_lms.format_message('package://%s.%s', $$PLSQL_UNIT_OWNER, $$PLSQL_UNIT);      
$if oracle_tools.cfg_pkg.c_debugging $then
    exception
      when others
      then
        dbug.print(dbug."error", 'l_statement: %s', l_statement);
        dbug.on_error;
        raise;     
$end
    end;

    if l_groups_to_process_tab.count = 0
    then
      raise_application_error
      ( c_no_groups_to_process
      , c_no_groups_to_process_msg
      );
    end if;

    l_groups_to_process_list := oracle_tools.api_pkg.collection2list(p_value_tab => l_groups_to_process_tab, p_sep => ',', p_ignore_null => 1);
  end check_input_and_state;

  procedure define_jobs
  is
  begin
    -- Create the supervisor
    l_job_name_tab.extend(1);
    l_job_name_tab(l_job_name_tab.last) := join_job_name(p_processing_package, c_program_worker_group);
    -- Create the workers
    for i_worker in 1 .. nvl(p_nr_workers_exact, p_nr_workers_each_group * l_groups_to_process_tab.count)
    loop
      l_job_name_tab.extend(1);
      l_job_name_tab(l_job_name_tab.last) := join_job_name(p_processing_package, c_program_worker_group, i_worker);
    end loop;
  end define_jobs;

  procedure start_jobs
  is
    l_processing_package_dummy all_objects.object_name%type;
    l_program_name_dummy user_scheduler_programs.program_name%type;
    l_worker_nr positive;
  begin
    if l_job_name_tab.count > 1 -- including supervisor
    then
      for i_idx in l_job_name_tab.first .. l_job_name_tab.last
      loop
        split_job_name
        ( p_job_name => l_job_name_tab(i_idx)
        , p_processing_package => l_processing_package_dummy
        , p_program_name => l_program_name_dummy
        , p_worker_nr => l_worker_nr 
        );

        -- submit but when job already exists: ignore
        begin
          submit_processing
          ( p_processing_package => p_processing_package
          , p_groups_to_process_list => l_groups_to_process_list
          , p_nr_workers => l_job_name_tab.count - 1 -- minus supervisor
          , p_worker_nr => l_worker_nr
          , p_end_date => l_end_date
          );
        exception
          when e_job_already_running
          then null;
        end;
      end loop;
    end if;
  end start_jobs;

  procedure cleanup
  is
  begin
    done;
  end cleanup;
begin
  init;
  
$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.enter($$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.LAUNCHER_PROCESSING');
  dbug.print
  ( dbug."input"
  , utl_lms.format_message
    ( 'p_processing_package: %s; p_nr_workers_each_group: %d; p_nr_workers_exact: %d'
    , p_processing_package
    , p_nr_workers_each_group
    , p_nr_workers_exact
    )
  );
$end

  check_input_and_state;
  define_jobs;
  start_jobs;

$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.leave;
$end

  cleanup; -- after dbug.leave since the done inside will change dbug state

exception
  when others
  then
$if oracle_tools.cfg_pkg.c_debugging $then  
    dbug.leave_on_error;
$end

    cleanup; -- after dbug.leave_on_error since the done inside will change dbug state
    raise;
end launcher_processing;

end msg_scheduler_pkg;
/

