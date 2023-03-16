CREATE OR REPLACE PACKAGE BODY "API_HEARTBEAT_PKG" -- -*-coding: utf-8-*-
is

-- private
subtype pipename_t is supervisor_channel_t;
subtype timestamp_str_t is api_time_pkg.timestamp_str_t;

"yyyy-mm-dd hh24:mi:ss" constant varchar2(30) := 'yyyy-mm-dd hh24:mi:ss';

function get_pipename
( p_supervisor_channel in supervisor_channel_t
, p_worker_nr in positive
)
return pipename_t
is
begin
  return p_supervisor_channel || case when p_worker_nr is not null then '#' || to_char(p_worker_nr) end;
end get_pipename;

procedure determine_silent_workers
( p_silence_threshold in api_time_pkg.seconds_t -- the number of seconds the supervisor may be silent before being added to the silent workers
, p_timestamp_tab in timestamp_tab_t
, p_silent_worker_tab out nocopy silent_worker_tab_t
)
is
  l_current_timestamp constant api_time_pkg.timestamp_t := api_time_pkg.get_timestamp;
  l_worker_nr natural; -- 0 (or null) is the supervisor
  l_delta api_time_pkg.seconds_t;
  l_silent_worker boolean;
begin
$if oracle_tools.api_heartbeat_pkg.c_debugging $then
  dbug.enter($$PLSQL_UNIT || '.DETERMINE_SILENT_WORKERS');
  dbug.print
  ( dbug."input"
  , 'p_silence_threshold: %s; p_timestamp_tab.count: %s; current timestamp: %s'
  , p_silence_threshold
  , p_timestamp_tab.count
  , api_time_pkg.timestamp2str(l_current_timestamp)
  );
$end

  p_silent_worker_tab := sys.odcinumberlist();
  l_worker_nr := p_timestamp_tab.first;
  while l_worker_nr is not null
  loop
    l_delta := api_time_pkg.delta(p_timestamp_tab(l_worker_nr), l_current_timestamp);
    l_silent_worker := ( p_timestamp_tab(l_worker_nr) is null or l_delta > p_silence_threshold );
        
$if oracle_tools.api_heartbeat_pkg.c_debugging $then
    dbug.print
    ( dbug."info"
    , 'silent worker %s; last timestamp received: %s; delta: %s; add silent worker: %s'
    , l_worker_nr
    , api_time_pkg.timestamp2str(p_timestamp_tab(l_worker_nr))
    , l_delta
    , dbug.cast_to_varchar2(l_silent_worker)
    );
$end

    if l_silent_worker
    then
      p_silent_worker_tab.extend(1);
      p_silent_worker_tab(p_silent_worker_tab.last) := case when l_worker_nr > 0 then l_worker_nr end;
    end if;
    
    l_worker_nr := p_timestamp_tab.next(l_worker_nr);
  end loop;

$if oracle_tools.api_heartbeat_pkg.c_debugging $then
  dbug.print(dbug."output", 'p_silent_worker_tab.count: %s', p_silent_worker_tab.count);
  dbug.leave;
exception
  when others
  then
    dbug.leave_on_error;
    raise;
$end
end determine_silent_workers;

$if false $then

function unpack_message
return varchar2
is
  l_number number;
  l_varchar2 varchar2(32767);
  l_rowid rowid;
  l_date date;
  l_raw raw(2000);
begin
  case dbms_pipe.next_item_type
    when 0 -- No more items
    then      
$if oracle_tools.api_heartbeat_pkg.c_debugging $then      
      dbug.print(dbug."info", 'no more items');
$end
      raise no_data_found;
      
    when 6 -- NUMBER
    then
      dbms_pipe.unpack_message(l_number);
$if oracle_tools.api_heartbeat_pkg.c_debugging $then      
      dbug.print(dbug."info", 'next item is a number: %s', to_char(l_number));
$end
      return to_char(l_number);
      
    when 9 -- VARCHAR2
    then
      dbms_pipe.unpack_message(l_varchar2);
$if oracle_tools.api_heartbeat_pkg.c_debugging $then      
      dbug.print(dbug."info", 'next item is a varchar2: %s', l_varchar2);
$end
      return l_varchar2;
      
    when 11 -- ROWID
    then      
      dbms_pipe.unpack_message(l_rowid);
$if oracle_tools.api_heartbeat_pkg.c_debugging $then      
      dbug.print(dbug."info", 'next item is a rowid: %s', l_rowid);
$end
      return rowidtochar(l_rowid);
      
    when 12 -- DATE
    then
      dbms_pipe.unpack_message(l_date);
$if oracle_tools.api_heartbeat_pkg.c_debugging $then      
      dbug.print(dbug."info", 'next item is a date: %s', to_char(l_date, "yyyy-mm-dd hh24:mi:ss"));
$end
      return to_char(l_date, "yyyy-mm-dd hh24:mi:ss");
      
    when 23 -- RAW
    then      
      dbms_pipe.unpack_message(l_raw);
$if oracle_tools.api_heartbeat_pkg.c_debugging $then      
      dbug.print(dbug."info", 'next item is a raw: %s', utl_raw.cast_to_varchar2(l_raw));
$end
      return utl_raw.cast_to_varchar2(l_raw);
  end case;
  
  return null;
end unpack_message;

$end

-- public
procedure init
( p_supervisor_channel in supervisor_channel_t
, p_worker_nr in positive
, p_max_worker_nr in naturaln
, p_timestamp_tab out nocopy timestamp_tab_t
)
is
  pragma inline (get_pipename, 'YES');
  l_pipename constant pipename_t := get_pipename(p_supervisor_channel, p_worker_nr);
  l_current_timestamp constant api_time_pkg.timestamp_t := api_time_pkg.get_timestamp;
begin
$if oracle_tools.api_heartbeat_pkg.c_debugging $then
  dbug.enter($$PLSQL_UNIT || '.INIT');
  dbug.print
  ( dbug."input"
  , 'p_supervisor_channel: %s; p_worker_nr: %s; p_max_worker_nr: %s; current timestamp: %s'
  , p_supervisor_channel
  , p_worker_nr
  , p_max_worker_nr
  , api_time_pkg.timestamp2str(l_current_timestamp)
  );
$end

  -- try to create a private pipe and if that fails purge it
  begin
    if dbms_pipe.remove_pipe(l_pipename) = 0 and
       dbms_pipe.create_pipe(pipename => l_pipename, private => true) = 0
    then
      null;
    else
      raise program_error; -- should not happen
    end if;
  exception
    when others
    then dbms_pipe.purge(l_pipename);
  end;

  p_timestamp_tab(p_max_worker_nr) := l_current_timestamp;
  for i_idx in 1 .. p_max_worker_nr
  loop
    p_timestamp_tab(i_idx) := l_current_timestamp;
  end loop;

$if oracle_tools.api_heartbeat_pkg.c_debugging $then
  dbug.print(dbug."output", 'p_timestamp_tab.count: %s', p_timestamp_tab.count);
  dbug.leave;
exception
  when others
  then
    dbug.leave_on_error;
    raise;
$end
end init;
 
procedure done
( p_supervisor_channel in supervisor_channel_t
, p_worker_nr in positive
)
is
begin
  pragma inline (get_pipename, 'YES');
  if dbms_pipe.remove_pipe(get_pipename(p_supervisor_channel, p_worker_nr)) = 0
  then
    null;
  end if;
end done;
 
procedure shutdown
( p_supervisor_channel in supervisor_channel_t
)
is
  l_result pls_integer;
  pragma inline (get_pipename, 'YES');
  l_send_pipe constant pipename_t := get_pipename(p_supervisor_channel, null);
  l_send_timeout constant naturaln := 0;
begin
$if oracle_tools.api_heartbeat_pkg.c_debugging $then
  dbug.enter($$PLSQL_UNIT || '.SHUTDOWN');
  dbug.print(dbug."input", 'p_supervisor_channel: %s', p_supervisor_channel);
$end

  dbms_pipe.reset_buffer;
  dbms_pipe.pack_message(c_shutdown_msg_int);
  l_result := dbms_pipe.send_message(pipename => l_send_pipe, timeout => l_send_timeout);
$if oracle_tools.api_heartbeat_pkg.c_debugging $then
  dbug.print(dbug."info", 'dbms_pipe.send_message(pipename => %s, timeout => %s): %s', l_send_pipe, l_send_timeout, l_result);
$end

  if l_result = 0
  then
    null; -- OK
  else
    raise_application_error
    ( c_shutdown_request_failed
    , utl_lms.format_message
      ( q'[Failed to send shutdown request. DBMS_PIPE.SEND_MESSAGE(pipename => '%s', timeout => %d) returned status %d.]'
      , l_send_pipe
      , l_send_timeout -- %d should work for naturaln
      , l_result -- %d should work for pls_integer
      )
    );
  end if;  

$if oracle_tools.api_heartbeat_pkg.c_debugging $then
  dbug.leave;
exception
  when others
  then
    dbug.leave_on_error;
    raise;
$end
end shutdown;

procedure send
( p_supervisor_channel in supervisor_channel_t
, p_worker_nr in positiven
, p_silence_threshold in api_time_pkg.seconds_t
, p_first_recv_timeout in naturaln
, p_timestamp_tab in out nocopy timestamp_tab_t
, p_silent_worker_tab out nocopy silent_worker_tab_t
)
is
  l_result pls_integer;
  l_current_timestamp constant api_time_pkg.timestamp_t := api_time_pkg.get_timestamp;
  l_send_timestamp_str constant timestamp_str_t := api_time_pkg.timestamp2str(l_current_timestamp);
  l_recv_timestamp_str timestamp_str_t := null;
  pragma inline (get_pipename, 'YES');
  l_send_pipe constant pipename_t := get_pipename(p_supervisor_channel, null);
  l_send_timeout constant naturaln := 0;
  pragma inline (get_pipename, 'YES');
  l_recv_pipe constant pipename_t := get_pipename(p_supervisor_channel, p_worker_nr);
  l_recv_timeout naturaln := p_first_recv_timeout;
  l_msg timestamp_str_t;
begin  
$if oracle_tools.api_heartbeat_pkg.c_debugging $then
  dbug.enter($$PLSQL_UNIT || '.SEND');
  dbug.print
  ( dbug."input"
  , 'p_supervisor_channel: %s; p_worker_nr: %s; p_silence_threshold: %s; p_first_recv_timeout: %s; current timestamp: %s'
  , p_supervisor_channel
  , p_worker_nr
  , p_silence_threshold
  , p_first_recv_timeout
  , api_time_pkg.timestamp2str(l_current_timestamp)  
  );
$end

  -- step 1 (see the package specification for the step description)
  dbms_pipe.reset_buffer;
  dbms_pipe.pack_message(p_worker_nr);
  dbms_pipe.pack_message(l_send_timestamp_str);
  l_result := dbms_pipe.send_message(pipename => l_send_pipe, timeout => l_send_timeout);
$if oracle_tools.api_heartbeat_pkg.c_debugging $then
  dbug.print(dbug."info", 'current timestamp to send to supervisor: %s', l_send_timestamp_str);
  dbug.print(dbug."info", 'dbms_pipe.send_message(pipename => %s, timeout => %s): %s', l_send_pipe, l_send_timeout, l_result);
$end

  -- step 2
  if l_result = 0
  then
    -- step 3
    <<recv_loop>>
    loop
      dbms_pipe.reset_buffer;
      l_result := dbms_pipe.receive_message(pipename => l_recv_pipe, timeout => l_recv_timeout);
      
$if oracle_tools.api_heartbeat_pkg.c_debugging $then
      dbug.print(dbug."info", 'dbms_pipe.receive_message(pipename => %s, timeout => %s): %s', l_recv_pipe, l_recv_timeout, l_result);
$end
      -- step 4
      exit when nvl(l_result, -1) <> 0;

      -- step 5
      l_recv_timeout := 0;

      -- step 6
      dbms_pipe.unpack_message(l_msg);
      if l_msg = c_shutdown_msg_str
      then
        raise_application_error(c_shutdown_request_received, 'Shutdown request received.');
      end if;
      
      -- step 7
      l_recv_timestamp_str := l_msg;
$if oracle_tools.api_heartbeat_pkg.c_debugging $then
      dbug.print(dbug."info", 'timestamp received from supervisor: %s', l_recv_timestamp_str);
$end
      p_timestamp_tab(0) := api_time_pkg.str2timestamp(l_recv_timestamp_str);
$if oracle_tools.api_heartbeat_pkg.c_debugging $then
      dbug.print(dbug."info", 'p_timestamp_tab(0): %s', l_recv_timestamp_str);
$end

      -- step 8
    end loop recv_loop;
  end if;

  -- step 9
  determine_silent_workers(p_silence_threshold, p_timestamp_tab, p_silent_worker_tab);

$if oracle_tools.api_heartbeat_pkg.c_debugging $then
  dbug.print
  ( dbug."output"
  , 'p_timestamp_tab.count: %s; p_silent_worker_tab.count: %s'
  , p_timestamp_tab.count
  , p_silent_worker_tab.count
  );
  dbug.leave;
exception
  when others
  then
    dbug.leave_on_error;
    raise;
$end
end send;    
  
procedure recv
( p_supervisor_channel in supervisor_channel_t
, p_silence_threshold in api_time_pkg.seconds_t -- the number of seconds the supervisor may be silent before being added to the silent workers
, p_first_recv_timeout in naturaln default 0 -- first receive timeout in seconds
, p_shutdown in out nocopy boolean -- is a shutdown in progress?
, p_timestamp_tab in out nocopy timestamp_tab_t
, p_silent_worker_tab out nocopy silent_worker_tab_t
)
is
  l_result pls_integer;
  l_current_timestamp api_time_pkg.timestamp_t := null;
  l_send_timestamp_str timestamp_str_t := null;
  l_recv_timestamp_str timestamp_str_t := null;
  l_send_pipe pipename_t := null;
  l_send_timeout constant naturaln := 0; -- step 3
  pragma inline (get_pipename, 'YES');
  l_recv_pipe constant pipename_t := get_pipename(p_supervisor_channel, null);
  l_recv_timeout naturaln := p_first_recv_timeout;
  l_worker_nr positive;
  l_msg pls_integer;
begin
$if oracle_tools.api_heartbeat_pkg.c_debugging $then
  dbug.enter($$PLSQL_UNIT || '.RECV');
  dbug.print
  ( dbug."input"
  , 'p_supervisor_channel: %s; p_silence_threshold: %s; p_first_recv_timeout: %s; p_shutdown: %s'
  , p_supervisor_channel
  , p_silence_threshold
  , p_first_recv_timeout
  , dbug.cast_to_varchar2(p_shutdown)
  );
$end

  if p_shutdown is null
  then
    raise value_error;
  end if;

  loop
    -- step 1 (see the package specification for the step description)
    dbms_pipe.reset_buffer;
    l_result := dbms_pipe.receive_message(pipename => l_recv_pipe, timeout => l_recv_timeout);
$if oracle_tools.api_heartbeat_pkg.c_debugging $then
    dbug.print(dbug."info", 'dbms_pipe.receive_message(pipename => %s, timeout => %s): %s', l_recv_pipe, l_recv_timeout, l_result);
$end

    -- step 2
    exit when nvl(l_result, -1) <> 0;

    -- step 3
    l_recv_timeout := 0;

    -- step 4
    dbms_pipe.unpack_message(l_msg);
    if l_msg = c_shutdown_msg_int
    then
      -- step 4a
      p_shutdown := true;
      l_worker_nr := null;
      continue; -- go back to step 1
    else
      -- step 4b
      l_worker_nr := l_msg;
      dbms_pipe.unpack_message(l_recv_timestamp_str);

$if oracle_tools.api_heartbeat_pkg.c_debugging $then
      dbug.print(dbug."info", 'timestamp received from worker: %s', l_recv_timestamp_str);
$end
    end if;

    if l_worker_nr is null
    then
      raise program_error;
    end if;

    -- step 5
    dbms_pipe.reset_buffer;
    if not(p_shutdown)
    then
      l_current_timestamp := api_time_pkg.get_timestamp;
      l_send_timestamp_str := api_time_pkg.timestamp2str(l_current_timestamp);

$if oracle_tools.api_heartbeat_pkg.c_debugging $then
      dbug.print(dbug."info", 'current timestamp to send to worker: %s', l_send_timestamp_str);
$end
      dbms_pipe.pack_message(l_send_timestamp_str);
    else
      dbms_pipe.pack_message(c_shutdown_msg_str);      
    end if;
    pragma inline (get_pipename, 'YES');
    l_send_pipe := get_pipename(p_supervisor_channel, l_worker_nr);
    l_result := dbms_pipe.send_message(pipename => l_send_pipe, timeout => l_send_timeout);
$if oracle_tools.api_heartbeat_pkg.c_debugging $then
    dbug.print(dbug."info", 'dbms_pipe.send_message(pipename => %s, timeout => %s): %s', l_send_pipe, l_send_timeout, l_result);
$end

    -- step 6
    exit when nvl(l_result, -1) <> 0;

    if not(p_shutdown)
    then
      -- step 7a
      p_timestamp_tab(l_worker_nr) := api_time_pkg.str2timestamp(l_recv_timestamp_str);
$if oracle_tools.api_heartbeat_pkg.c_debugging $then
      dbug.print(dbug."info", 'p_timestamp_tab(%s): %s', l_worker_nr, l_recv_timestamp_str);
$end
    else
      -- step 7b
      if p_timestamp_tab.exists(l_worker_nr)
      then
        p_timestamp_tab.delete(l_worker_nr);
      end if;
$if oracle_tools.api_heartbeat_pkg.c_debugging $then
      dbug.print(dbug."info", 'p_timestamp_tab(%s) deleted', l_worker_nr);
$end
      if p_timestamp_tab.count = 0
      then
        raise_application_error(c_shutdown_request_completed, 'Shutdown request completed.');
      end if;
    end if;

    -- step 8
  end loop;

  -- step 9
  determine_silent_workers(p_silence_threshold, p_timestamp_tab, p_silent_worker_tab);

$if oracle_tools.api_heartbeat_pkg.c_debugging $then
  dbug.print
  ( dbug."output"
  , 'p_shutdown: %s; p_timestamp_tab.count: %s; p_silent_worker_tab.count: %s'
  , dbug.cast_to_varchar2(p_shutdown)
  , p_timestamp_tab.count
  , p_silent_worker_tab.count
  );
  dbug.leave;
exception
  when others
  then
    dbug.leave_on_error;
    raise;
$end
end recv;    

$if oracle_tools.cfg_pkg.c_testing $then

procedure ut_ping_pong
is
  l_supervisor_channel constant supervisor_channel_t := $$PLSQL_UNIT;
  l_timestamp_tab timestamp_tab_t;
  l_first_timestamp_tab timestamp_tab_t;
  l_silent_worker_tab silent_worker_tab_t;
  l_timeout constant integer := 5;
  l_shutdown boolean := false;
begin
$if oracle_tools.api_heartbeat_pkg.c_debugging $then
  dbug.enter($$PLSQL_UNIT || '.UT_PING_PONG');
$end

  -- supervisor
  init
  ( p_supervisor_channel => l_supervisor_channel
  , p_worker_nr => null
  , p_max_worker_nr => 1
  , p_timestamp_tab => l_timestamp_tab
  );
  l_first_timestamp_tab(1) := l_timestamp_tab(1);
  -- worker
  init
  ( p_supervisor_channel => l_supervisor_channel
  , p_worker_nr => 1
  , p_max_worker_nr => 0
  , p_timestamp_tab => l_timestamp_tab
  );
  l_first_timestamp_tab(0) := l_timestamp_tab(0);
  
  l_timestamp_tab := l_first_timestamp_tab;

  -- send twice a heartbeat without a supervisor receiving it
  for i_case in 1..4
  loop
$if oracle_tools.api_heartbeat_pkg.c_debugging $then
    dbug.print(dbug."info", 'i_case: %s', i_case);
$end
    case
      when i_case in (1, 2)
      then
        send
        ( p_supervisor_channel => l_supervisor_channel
        , p_worker_nr => 1
        , p_silence_threshold => l_timeout
        , p_first_recv_timeout => case i_case when 1 then 0 else l_timeout end
        , p_timestamp_tab => l_timestamp_tab
        , p_silent_worker_tab => l_silent_worker_tab
        );
        ut.expect(l_timestamp_tab(0), 'last supervisor timestamp #' || i_case).to_equal(l_first_timestamp_tab(0));    
        ut.expect(l_timestamp_tab(1), 'last worker timestamp #' || i_case).to_equal(l_first_timestamp_tab(1));
        -- both the supervisor and worker are silent the second case
        ut.expect(l_silent_worker_tab.count, 'silent worker count #' || i_case).to_equal(case i_case when 1 then 0 else 2 end);
        
      when i_case = 3
      then
        recv
        ( p_supervisor_channel => l_supervisor_channel
        , p_silence_threshold => l_timeout
        , p_first_recv_timeout => l_timeout
        , p_shutdown => l_shutdown
        , p_timestamp_tab => l_timestamp_tab
        , p_silent_worker_tab => l_silent_worker_tab
        );
        ut.expect(l_shutdown, 'shutdown #' || i_case).to_be_false();    
        ut.expect(l_timestamp_tab(0), 'last supervisor timestamp #' || i_case).to_equal(l_first_timestamp_tab(0));    
        ut.expect(l_timestamp_tab(1), 'last worker timestamp #' || i_case).to_be_greater_than(l_first_timestamp_tab(1));    
        ut.expect(l_silent_worker_tab.count, 'silent worker count #' || i_case).to_equal(2);
        
      when i_case = 4
      then
        send
        ( p_supervisor_channel => l_supervisor_channel
        , p_worker_nr => 1
        , p_silence_threshold => l_timeout
        , p_first_recv_timeout => 0
        , p_timestamp_tab => l_timestamp_tab
        , p_silent_worker_tab => l_silent_worker_tab
        );
        ut.expect(l_timestamp_tab(0), 'last supervisor timestamp #' || i_case).to_be_greater_than(l_first_timestamp_tab(0));    
        ut.expect(l_timestamp_tab(1), 'last worker timestamp #' || i_case).to_be_greater_than(l_first_timestamp_tab(1));    
        ut.expect(l_silent_worker_tab.count, 'silent worker count #' || i_case).to_equal(1); -- worker is too late
    end case;

    -- common checks
    ut.expect(l_timestamp_tab.count, 'timestamp count #' || i_case).to_equal(2);
    if l_silent_worker_tab.count = 2
    then
      ut.expect(l_silent_worker_tab(1), 'silent worker 1 #' || i_case).to_be_null;
      ut.expect(l_silent_worker_tab(2), 'silent worker 2 #' || i_case).to_equal(1);
    end if;
  end loop;

$if oracle_tools.api_heartbeat_pkg.c_debugging $then
  dbug.leave;
exception
  when others
  then
    dbug.leave_on_error;
    raise;
$end
end ut_ping_pong;

procedure ut_shutdown_worker
is
  l_supervisor_channel constant supervisor_channel_t := $$PLSQL_UNIT;
  l_supervisor_timestamp_tab timestamp_tab_t;
  l_worker1_timestamp_tab timestamp_tab_t;
  l_worker2_timestamp_tab timestamp_tab_t;
  l_silent_worker_tab silent_worker_tab_t;
  l_shutdown boolean := false;
begin
$if oracle_tools.api_heartbeat_pkg.c_debugging $then
  dbug.enter($$PLSQL_UNIT || '.UT_SHUTDOWN_WORKER');
$end

  -- supervisor
  init
  ( p_supervisor_channel => l_supervisor_channel
  , p_worker_nr => null
  , p_max_worker_nr => 2
  , p_timestamp_tab => l_supervisor_timestamp_tab
  );
  -- worker 1
  init
  ( p_supervisor_channel => l_supervisor_channel
  , p_worker_nr => 1
  , p_max_worker_nr => 0
  , p_timestamp_tab => l_worker1_timestamp_tab
  );
  -- worker 2
  init
  ( p_supervisor_channel => l_supervisor_channel
  , p_worker_nr => 2
  , p_max_worker_nr => 0
  , p_timestamp_tab => l_worker2_timestamp_tab
  );

$if oracle_tools.api_heartbeat_pkg.c_debugging $then
  dbug.print(dbug."info", 'part 1');
$end

  -- send two messages without any consequences
  send
  ( p_supervisor_channel => l_supervisor_channel
  , p_worker_nr => 1
  , p_silence_threshold => 10 -- a lot higher than the timeout
  , p_first_recv_timeout => 0
  , p_timestamp_tab => l_worker1_timestamp_tab
  , p_silent_worker_tab => l_silent_worker_tab
  );
  ut.expect(l_silent_worker_tab.count, 'supervisor not silent for worker 1').to_equal(0);
  send
  ( p_supervisor_channel => l_supervisor_channel
  , p_worker_nr => 2
  , p_silence_threshold => 10
  , p_first_recv_timeout => 0
  , p_timestamp_tab => l_worker2_timestamp_tab
  , p_silent_worker_tab => l_silent_worker_tab
  );
  ut.expect(l_silent_worker_tab.count, 'supervisor not silent for worker 2').to_equal(0);

  -- turns the supervisor into shutdown mode as soon as it is received
  shutdown(p_supervisor_channel => l_supervisor_channel);

  -- 1. the supervisor will receive first the two heartbeats
  -- 2. it will respond to them normally
  -- 3. next it will receive the shutdown request and turn the supervisor in shutdown mode
  recv
  ( p_supervisor_channel => l_supervisor_channel
  , p_silence_threshold => 10
  , p_first_recv_timeout => 0
  , p_shutdown => l_shutdown
  , p_timestamp_tab => l_supervisor_timestamp_tab
  , p_silent_worker_tab => l_silent_worker_tab
  );
  ut.expect(l_shutdown, 'shutdown mode').to_be_true();

$if oracle_tools.api_heartbeat_pkg.c_debugging $then
  dbug.print(dbug."info", 'part 2');
$end

  -- send again two messages and let the sueprvisor receive them while responding with a shutdown request
  send
  ( p_supervisor_channel => l_supervisor_channel
  , p_worker_nr => 1
  , p_silence_threshold => 10
  , p_first_recv_timeout => 0
  , p_timestamp_tab => l_worker1_timestamp_tab
  , p_silent_worker_tab => l_silent_worker_tab
  );
  send
  ( p_supervisor_channel => l_supervisor_channel
  , p_worker_nr => 2
  , p_silence_threshold => 1
  , p_first_recv_timeout => 0
  , p_timestamp_tab => l_worker2_timestamp_tab
  , p_silent_worker_tab => l_silent_worker_tab
  );
  begin
    recv
    ( p_supervisor_channel => l_supervisor_channel
    , p_silence_threshold => 10
    , p_first_recv_timeout => 0
    , p_shutdown => l_shutdown
    , p_timestamp_tab => l_supervisor_timestamp_tab
    , p_silent_worker_tab => l_silent_worker_tab
    );
    -- should not come here
    raise program_error;
  exception
    when e_shutdown_request_completed
    then
      -- reinitialise the timestamp table
      init
      ( p_supervisor_channel => l_supervisor_channel
      , p_worker_nr => null
      , p_max_worker_nr => 2
      , p_timestamp_tab => l_supervisor_timestamp_tab
      );
  end;

$if oracle_tools.api_heartbeat_pkg.c_debugging $then
  dbug.print(dbug."info", 'part 3');
$end

  -- send two more messages: should fail since the supervisor has already sent a shutdown request
  begin
    send
    ( p_supervisor_channel => l_supervisor_channel
    , p_worker_nr => 1
    , p_silence_threshold => 10
    , p_first_recv_timeout => 0
    , p_timestamp_tab => l_worker1_timestamp_tab
    , p_silent_worker_tab => l_silent_worker_tab
    );
    -- should not come here
    raise program_error;
  exception
    when e_shutdown_request_received
    then
      null;
  end;

  -- this one should also fail with e_shutdown_request_received and that is the outcome of the test
  send
  ( p_supervisor_channel => l_supervisor_channel
  , p_worker_nr => 2
  , p_silence_threshold => 1
  , p_first_recv_timeout => 0
  , p_timestamp_tab => l_worker2_timestamp_tab
  , p_silent_worker_tab => l_silent_worker_tab
  );

$if oracle_tools.api_heartbeat_pkg.c_debugging $then
  dbug.leave;
exception
  when others
  then
    dbug.leave_on_error;
    raise;
$end
end ut_shutdown_worker;

procedure ut_shutdown_supervisor
is
  l_supervisor_channel constant supervisor_channel_t := $$PLSQL_UNIT;
  l_supervisor_timestamp_tab timestamp_tab_t;
  l_worker1_timestamp_tab timestamp_tab_t;
  l_worker2_timestamp_tab timestamp_tab_t;
  l_silent_worker_tab silent_worker_tab_t;
  l_shutdown boolean := false;
begin
$if oracle_tools.api_heartbeat_pkg.c_debugging $then
  dbug.enter($$PLSQL_UNIT || '.UT_SHUTDOWN_SUPERVISOR');
$end

  -- supervisor
  init
  ( p_supervisor_channel => l_supervisor_channel
  , p_worker_nr => null
  , p_max_worker_nr => 2
  , p_timestamp_tab => l_supervisor_timestamp_tab
  );
  -- worker 1
  init
  ( p_supervisor_channel => l_supervisor_channel
  , p_worker_nr => 1
  , p_max_worker_nr => 0
  , p_timestamp_tab => l_worker1_timestamp_tab
  );
  -- worker 2
  init
  ( p_supervisor_channel => l_supervisor_channel
  , p_worker_nr => 2
  , p_max_worker_nr => 0
  , p_timestamp_tab => l_worker2_timestamp_tab
  );

  -- turns the supervisor into shutdown mode
  shutdown(p_supervisor_channel => l_supervisor_channel);

  -- send two messages without any immediate consequences
  send
  ( p_supervisor_channel => l_supervisor_channel
  , p_worker_nr => 1
  , p_silence_threshold => 10 -- a lot higher than the timeout
  , p_first_recv_timeout => 0
  , p_timestamp_tab => l_worker1_timestamp_tab
  , p_silent_worker_tab => l_silent_worker_tab
  );
  ut.expect(l_silent_worker_tab.count, 'supervisor not silent for worker 1').to_equal(0);
  send
  ( p_supervisor_channel => l_supervisor_channel
  , p_worker_nr => 2
  , p_silence_threshold => 10
  , p_first_recv_timeout => 0
  , p_timestamp_tab => l_worker2_timestamp_tab
  , p_silent_worker_tab => l_silent_worker_tab
  );
  ut.expect(l_silent_worker_tab.count, 'supervisor not silent for worker 2').to_equal(0);

  -- 1. first it will receive the shutdown request
  -- 2. next it will receive the two heartbeats
  -- 3. it will respond to them with a shutdown message
  -- 4. and at the same time it will empty the timestamp table, hence an exception (the outcome of this test)
  recv
  ( p_supervisor_channel => l_supervisor_channel
  , p_silence_threshold => 10
  , p_first_recv_timeout => 0
  , p_shutdown => l_shutdown
  , p_timestamp_tab => l_supervisor_timestamp_tab
  , p_silent_worker_tab => l_silent_worker_tab
  );

$if oracle_tools.api_heartbeat_pkg.c_debugging $then
  dbug.leave;
exception
  when others
  then
    dbug.leave_on_error;
    raise;
$end
end ut_shutdown_supervisor;

$end

end API_HEARTBEAT_PKG;
/

