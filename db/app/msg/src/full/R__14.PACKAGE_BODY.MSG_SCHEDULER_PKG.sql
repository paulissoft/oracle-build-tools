CREATE OR REPLACE PACKAGE BODY "MSG_SCHEDULER_PKG" AS

subtype job_name_t is user_scheduler_jobs.job_name%type;

"yyyymmddhh24miss" constant varchar2(16) := 'yyyymmddhh24miss';
"yyyy-mm-dd hh24:mi:ss" constant varchar2(21) := 'yyyy-mm-dd hh24:mi:ss';

c_program_launcher constant user_scheduler_programs.program_name%type := 'PROCESSING_LAUNCHER';
c_program_worker constant user_scheduler_programs.program_name%type := 'PROCESSING';

c_schedule_launcher constant user_scheduler_programs.program_name%type := 'SCHEDULE_LAUNCHER';

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

    when c_program_worker
    then
      dbms_scheduler.create_program
      ( program_name => l_program_name
      , program_type => 'STORED_PROCEDURE'
      , program_action => $$PLSQL_UNIT || '.' || p_program_name -- program name is the same as module name
      , number_of_arguments => 4
      , enabled => false
      , comments => 'Worker program for processing messages supervised by the main job.'
      );
  
      for i_par_idx in 1..4
      loop
        dbms_scheduler.define_program_argument
        ( program_name => l_program_name
        , argument_name => case i_par_idx
                             when 1 then 'P_PROCESSING_PACKAGE'
                             when 2 then 'P_GROUPS_TO_PROCESS_LIST'
                             when 3 then 'P_JOB_NAME_LAUNCHER'
                             when 4 then 'P_WORKER_NR'
                           end
        , argument_position => i_par_idx
        , argument_type => case 
                             when i_par_idx <= 3
                             then 'VARCHAR2'
                             else 'NUMBER'
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
, p_job_name_launcher in varchar2
, p_worker_nr in positiven
, p_end_date in user_scheduler_jobs.end_date%type
)
is
  l_job_name_worker constant job_name_t := p_job_name_launcher || '#' || to_char(p_worker_nr);
  l_argument_value user_scheduler_program_args.default_value%type;
begin  
  PRAGMA INLINE (is_job_running, 'YES');
  if is_job_running(l_job_name_worker)
  then
    raise_application_error
    ( c_job_already_running
    , utl_lms.format_message
      ( c_job_already_running_msg
      , l_job_name_worker
      )
    );
  end if;
  
  PRAGMA INLINE (does_job_exist, 'YES');
  if not(does_job_exist(l_job_name_worker))
  then  
    if not(does_program_exist(c_program_worker))
    then
      create_program(c_program_worker);
    end if;

    -- use inline schedule
    dbms_scheduler.create_job
    ( job_name => l_job_name_worker
    , program_name => c_program_worker
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
    dbms_scheduler.disable(l_job_name_worker);    
  end if;
  
  -- set the actual arguments

  for r in
  ( select  a.argument_name
    from    user_scheduler_jobs j
            inner join user_scheduler_program_args a
            on a.program_name = j.program_name
    where   j.job_name = l_job_name_worker
    order by
            a.argument_position
  )
  loop
    case r.argument_name
      when 'P_PROCESSING_PACKAGE'
      then l_argument_value := p_processing_package;
      when 'P_GROUPS_TO_PROCESS_LIST'
      then l_argument_value := p_groups_to_process_list;
      when 'P_JOB_NAME_LAUNCHER'
      then l_argument_value := p_job_name_launcher;
      when 'P_WORKER_NR'
      then l_argument_value := to_char(p_worker_nr);
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
    ( job_name => l_job_name_worker
    , argument_name => r.argument_name
    , argument_value => l_argument_value
    );
  end loop;
  
  dbms_scheduler.enable(l_job_name_worker);
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

procedure job_event_enable
( p_job_name_launcher in varchar2
, p_worker_nr in positive
, p_enable in boolean
)
is
  -- ORA-24034: application ORACLE_TOOLS is already a subscriber for queue SYS.SCHEDULER$_EVENT_QUEUE
  e_already_subscriber exception;  
  pragma exception_init(e_already_subscriber, -24034);
begin
  if p_enable
  then
    dbms_scheduler.set_attribute
    ( name => p_job_name_launcher || '#' || to_char(p_worker_nr)
    , attribute => 'raise_events'
    , value => dbms_scheduler.job_failed + dbms_scheduler.job_stopped -- not interested in succeeded jobs
    );
    dbms_scheduler.add_event_queue_subscriber;
  else
    dbms_scheduler.set_attribute_null
    ( name => p_job_name_launcher || '#' || to_char(p_worker_nr)
    , attribute => 'raise_events'
    );
  end if;
exception
  when e_already_subscriber
  then null;
end job_event_enable;

-- Receive a job event for one of the worker jobs launched by this launcher.
procedure job_event_recv
( p_job_name_launcher in varchar2
, p_timeout in integer
, p_worker_nr out nocopy positive
, p_sqlcode out nocopy integer
, p_sqlerrm out nocopy varchar2
)
is
  pragma autonomous_transaction;
  
  l_dequeue_options     dbms_aq.dequeue_options_t;
  l_message_properties  dbms_aq.message_properties_t;
  l_message_handle      raw(16);
  l_queue_msg           sys.scheduler$_event_info;

  -- for split_job_name on the launcher
  l_processing_package_launcher all_objects.object_name%type;
  l_program_name_launcher user_scheduler_programs.program_name%type;
  l_worker_nr_launcher positive;
  
  -- for split_job_name on the completed job
  l_job_name_worker job_name_t;
  l_processing_package_worker all_objects.object_name%type;
  l_program_name_worker user_scheduler_programs.program_name%type;

  l_worker_type varchar2(3 char) := null; -- null or 'our' (co-worker)
begin
$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.enter($$PLSQL_UNIT || '.JOB_EVENT_RECV');
  dbug.print
  ( dbug."input"
  , 'p_job_name_launcher: %s; p_timeout: %s'
  , p_job_name_launcher
  , p_timeout
  );
$end

  p_worker_nr := null;
  p_sqlcode := null;
  p_sqlerrm := null;

  PRAGMA INLINE (split_job_name, 'YES');
  split_job_name
  ( p_job_name => p_job_name_launcher
  , p_processing_package => l_processing_package_launcher
  , p_program_name => l_program_name_launcher
  , p_worker_nr => l_worker_nr_launcher
  );

  -- some sanity checks
  if l_program_name_launcher = c_program_launcher
  then
    null;
  else
    raise value_error;
  end if;

  if l_worker_nr_launcher is null
  then
    null;
  else
    raise value_error;
  end if;

  -- The message dequeued may need to be processed by another process,
  -- since we receive all job status events in this schema.
  -- But since there should be only ONE launcher running for the SAME processing package (for now there is just one: MSG_AQ_PKG),
  -- we can REMOVE all messages for the same processing package.
  --
  -- The best way to ignore job events from OTHER processing packages is
  -- to LOCK and inspect whether the concerning job is one of the workers for this processing package.
  -- If it is one of our workers, REMOVE the message with the msgid just retrieved and COMMIT.
  -- Otherwise, just ignore the message and ROLLBACK.

  l_dequeue_options.consumer_name := $$PLSQL_UNIT_OWNER;

  <<step_loop>>
  for i_step in 1..2
  loop
$if oracle_tools.cfg_pkg.c_debugging $then
    dbug.print(dbug."info", 'i_step: %s', i_step);
$end

    if i_step = 1
    then
      l_dequeue_options.dequeue_mode := dbms_aq.locked;
      l_dequeue_options.wait := p_timeout;
    else
      l_dequeue_options.dequeue_mode := dbms_aq.remove;
      l_dequeue_options.wait := dbms_aq.no_wait; -- no need to wait since we alreay locked the message
      l_dequeue_options.msgid := l_message_handle;
    end if;
    
    dbms_aq.dequeue
    ( queue_name => msg_aq_pkg.c_job_event_queue_name
    , dequeue_options => l_dequeue_options
    , message_properties => l_message_properties
    , payload => l_queue_msg
    , msgid => l_message_handle
    );

    exit step_loop when i_step = 2;
    
    l_job_name_worker := l_queue_msg.object_name;

    l_worker_type :=
      case
        when l_job_name_worker like to_like_expr(p_job_name_launcher || '#%') escape '\'
        then 'our'
      end;
    
$if oracle_tools.cfg_pkg.c_debugging $then
    dbug.print
    ( dbug."info"
    , 'job name: %s; event type: %s; event timestamp: %s; worker type: %s'
    , l_job_name_worker
    , l_queue_msg.event_type
    , to_char(l_queue_msg.event_timestamp, "yyyymmddhh24miss")
    , l_worker_type
    );
$end

    if l_worker_type = 'our'
    then
      -- a co-worker
      
      PRAGMA INLINE (split_job_name, 'YES');
      split_job_name
      ( p_job_name => l_job_name_worker
      , p_processing_package => l_processing_package_worker
      , p_program_name => l_program_name_worker
      , p_worker_nr => p_worker_nr 
      );

      if p_worker_nr is not null
      then
        p_sqlcode := l_queue_msg.error_code;
        p_sqlerrm := l_queue_msg.error_msg;
      end if;
    end if;
  end loop step_loop;

  if l_worker_type is not null
  then
    commit;
  else
    rollback; -- give another processing package launcher a chance to process it
  end if;

$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.print
  ( dbug."output"
  , 'p_worker_nr: %s; p_sqlcode: %s; p_sqlerrm: %s'
  , p_worker_nr
  , p_sqlcode
  , p_sqlerrm
  );  
  dbug.leave;
exception
  when others
  then
    dbug.leave_on_error;
    raise;
$end
end job_event_recv;

procedure stop_job
( p_job_name in job_name_t
)
is
  procedure job_event_done
  is
  begin
    dbms_scheduler.set_attribute_null(name => p_job_name, attribute => 'raise_events');
  end job_event_done;
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

    job_event_done; -- stop signalling that this jobs has stopped / failed
    
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
, p_job_name_launcher in varchar2
, p_worker_nr in positiven
, p_end_date in user_scheduler_jobs.end_date%type
)
is
  l_processing_package constant all_objects.object_name%type := determine_processing_package(p_processing_package);
  l_job_name_worker constant job_name_t := session_job_name();
  l_stop constant boolean := p_end_date is null;
  l_statement varchar2(32767 byte);
  l_groups_to_process_tab sys.odcivarchar2list;

  -- ORA-06550: line 1, column 18:
  -- PLS-00302: component 'PROCESING' must be declared
  e_compilation_error exception;
  pragma exception_init(e_compilation_error, -6550);

  procedure restart_worker
  is
    l_worker_nr positive;
    l_sqlcode integer;
    l_sqlerrm varchar2(4000 char);
  begin    
    -- get the status
    job_event_recv
    ( p_job_name_launcher => p_job_name_launcher
    , p_timeout => 1 -- there should be one job event message ready
    , p_worker_nr => l_worker_nr 
    , p_sqlcode => l_sqlcode
    , p_sqlerrm => l_sqlerrm
    );

    if l_worker_nr is not null
    then
$if oracle_tools.cfg_pkg.c_debugging $then
      dbug.print
      ( case when l_sqlerrm is null then dbug."info" else dbug."error" end
      , 'Worker %s stopped with error code %s'
      , l_worker_nr
      , l_sqlcode
      );
      if l_sqlerrm is not null
      then
        dbug.print(dbug."error", l_sqlerrm);
      end if;
$end

      submit_processing
      ( p_processing_package => p_processing_package
      , p_groups_to_process_list => p_groups_to_process_list
      , p_job_name_launcher => p_job_name_launcher
      , p_worker_nr => l_worker_nr
      , p_end_date => p_end_date -- all workers are supposed to have the same end date
      );
    end if;
  end restart_worker;

  procedure cleanup
  is
  begin
    done;
  end cleanup;
begin
  job_event_enable
  ( p_job_name_launcher => p_job_name_launcher
  , p_worker_nr => p_worker_nr
  , p_enable => not(l_stop)
  );
  init;

$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.enter($$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.PROCESSING');
  dbug.print
  ( dbug."input"
  , 'p_processing_package: %s; p_groups_to_process_list: %s; p_job_name_launcher: %s; p_worker_nr: %s'
  , p_processing_package
  , p_groups_to_process_list
  , p_job_name_launcher
  , p_worker_nr
  );
$end

  if l_job_name_worker is null
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
                     ( 'call %s.processing(p_groups_to_process_tab => :1, p_worker_nr => :2, p_end_date => :3)'
                     , l_processing_package -- already checked by determine_processing_package
                     );

      begin
        execute immediate l_statement
          using in l_groups_to_process_tab, in p_worker_nr, in p_end_date;
          
        exit processing_loop; -- the processing just succeeded (no signal), so stop
      exception
        when e_compilation_error
        then
$if oracle_tools.cfg_pkg.c_debugging $then
          dbug.print(dbug."error", 'statement: %s', l_statement);
          dbug.on_error;
$end                  
          raise;

        when msg_aq_pkg.e_job_event_signal
        then
$if oracle_tools.cfg_pkg.c_debugging $then
          dbug.on_error;
$end
          restart_worker;
          -- no re-raise

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
  when msg_aq_pkg.e_stop_signal
  then
$if oracle_tools.cfg_pkg.c_debugging $then
    dbug.on_error;
$end
    cleanup;
    null;
    -- no re-raise

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
      , p_worker_nr => null
      );

    <<command_loop>>
    for i_command_idx in l_command_tab.first .. l_command_tab.last
    loop
$if oracle_tools.cfg_pkg.c_debugging $then
      dbug.print(dbug."info", 'l_command_tab(%s): %s', i_command_idx, l_command_tab(i_command_idx));
$end
      case l_command_tab(i_command_idx)
        when 'check_jobs_not_running'
        then
          PRAGMA INLINE (get_jobs, 'YES');
          l_job_names := get_jobs(l_job_name_launcher || '%', 'RUNNING');
          if l_job_names.count > 0
          then
            raise_application_error
            ( c_there_are_running_jobs
            , utl_lms.format_message
              ( c_there_are_running_jobs_msg
              , l_job_name_launcher || '%'
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
              submit_processing_launcher(p_processing_package => l_processing_package);
          end;

          -- Job is running or scheduled, but we may have to run workers between now and the next run date
          begin
            processing_launcher(p_processing_package => l_processing_package);
          exception
            when e_no_groups_to_process
            then null;
          end;

        when 'stop'
        then
          begin
            processing_launcher
            ( p_processing_package => l_processing_package
            , p_stop => 1
            );
          exception
            when e_no_groups_to_process
            then null;
          end;
          
          PRAGMA INLINE (get_jobs, 'YES');
          l_job_names := get_jobs( p_job_name_expr => l_job_name_launcher || '%');
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
              , 'trying to %s %s job %s'
              , case when l_worker_nr is null then 'stop and disable' else 'drop' end
              , case when l_worker_nr is null then 'launcher' else 'worker' end
              , l_job_names(i_job_idx)
              );
$end

              -- kill
              begin                  
                if l_worker_nr is null
                then
                  -- stop and disable a launcher job
                  PRAGMA INLINE (stop_job, 'YES');
                  stop_job(l_job_names(i_job_idx));
                  dbms_scheduler.disable(l_job_names(i_job_idx));
                else
                  -- drop worker jobs
                  PRAGMA INLINE (drop_job, 'YES');
                  drop_job(l_job_names(i_job_idx));
                end if;
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
            l_job_names := get_jobs(p_job_name_expr => l_job_name_launcher || '%');

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

procedure submit_processing_launcher
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
  dbug.enter($$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.SUBMIT_PROCESSING_LAUNCHER');
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
  
  dbms_scheduler.enable(l_job_name_launcher); -- start the job

$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.leave;
$end
end submit_processing_launcher;

procedure processing_launcher
( p_processing_package in varchar2
, p_nr_workers_each_group in positive
, p_nr_workers_exact in positive
, p_stop in naturaln
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
      if p_stop = 0
      then
        dbug.print
        ( dbug."warning"
        , utl_lms.format_message
          ( 'This session (SID=%s) does not appear to be a running job (for this user), see also column SESSION_ID from view USER_SCHEDULER_RUNNING_JOBS.'
          , to_char(c_session_id)
          )
        );
      end if;
$end
        
      l_job_name_launcher := 
        join_job_name
        ( p_processing_package => l_processing_package
        , p_program_name => c_program_launcher
        );
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
                   ( q'[begin :1 := %s.get_groups_to_process('package://%s.%s'); end;]'
                   , l_processing_package -- already checked by determine_processing_package
                   , $$PLSQL_UNIT_OWNER
                   , $$PLSQL_UNIT
                   );

    begin
      execute immediate l_statement using out l_groups_to_process_tab;      
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

  procedure define_workers
  is
  begin
    if p_stop = 0
    then
      -- Create the workers (need at least 2 to survey each other)
      for i_worker in 1 .. greatest(2, nvl(p_nr_workers_exact, p_nr_workers_each_group * l_groups_to_process_tab.count))
      loop
        l_job_name_tab.extend(1);
        l_job_name_tab(l_job_name_tab.last) := l_job_name_launcher || '#' || to_char(i_worker); -- the # indicates a worker job
      end loop;
    else
      l_job_name_tab := get_jobs(l_job_name_launcher || '%', 'RUNNING', 1);
    end if;
  end define_workers;

  procedure start_workers
  is
    l_processing_package_dummy all_objects.object_name%type;
    l_program_name_dummy user_scheduler_programs.program_name%type;
    l_worker_nr positive;
  begin
    if l_job_name_tab.count > 0
    then
      for i_idx in l_job_name_tab.first .. l_job_name_tab.last
      loop
        split_job_name
        ( p_job_name => l_job_name_tab(i_idx)
        , p_processing_package => l_processing_package_dummy
        , p_program_name => l_program_name_dummy
        , p_worker_nr => l_worker_nr 
        );

        if p_stop = 0
        then
          -- submit but when job already exists: ignore
          begin
            submit_processing
            ( p_processing_package => p_processing_package
            , p_groups_to_process_list => l_groups_to_process_list
            , p_job_name_launcher => l_job_name_launcher
            , p_worker_nr => l_worker_nr
            , p_end_date => l_end_date
            );
          exception
            when e_job_already_running
            then null;
          end;
        else
          processing
          ( p_processing_package => p_processing_package
          , p_groups_to_process_list => l_groups_to_process_list
          , p_job_name_launcher => l_job_name_launcher
          , p_worker_nr => l_worker_nr
          , p_end_date => null -- indicates stop
          );
        end if;
      end loop;
    end if;
  end start_workers;

  procedure cleanup
  is
  begin
    done;
  end cleanup;
begin
  init;
  
$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.enter($$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.PROCESSING_LAUNCHER');
  dbug.print
  ( dbug."input"
  , utl_lms.format_message
    ( 'p_processing_package: %s; p_nr_workers_each_group: %d; p_nr_workers_exact: %d; p_stop: %d'
    , p_processing_package
    , p_nr_workers_each_group
    , p_nr_workers_exact
    , p_stop
    )
  );
$end

  check_input_and_state;
  define_workers;
  start_workers;

$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.leave;
$end

  cleanup; -- after dbug.leave since the done inside will change dbug state

exception
  when msg_aq_pkg.e_dequeue_timeout
  then
$if oracle_tools.cfg_pkg.c_debugging $then  
    dbug.leave_on_error;
$end

    cleanup; -- after dbug.leave_on_error since the done inside will change dbug state
    -- no reraise necessary
    
  when others
  then
$if oracle_tools.cfg_pkg.c_debugging $then  
    dbug.leave_on_error;
$end

    cleanup; -- after dbug.leave_on_error since the done inside will change dbug state
    raise;
end processing_launcher;

procedure processing
( p_processing_package in varchar2 
, p_groups_to_process_list in varchar2
, p_job_name_launcher in varchar2
, p_worker_nr in positiven
)
is
  l_job_name_worker constant job_name_t := session_job_name();
  l_end_date user_scheduler_jobs.end_date%type := null;
begin
  select  j.end_date
  into    l_end_date
  from    user_scheduler_jobs j
  where   j.job_name = l_job_name_worker;

  processing
  ( p_processing_package => p_processing_package
  , p_groups_to_process_list => p_groups_to_process_list
  , p_job_name_launcher => p_job_name_launcher
  , p_worker_nr => p_worker_nr
  , p_end_date => l_end_date
  );
end processing;

end msg_scheduler_pkg;
/

