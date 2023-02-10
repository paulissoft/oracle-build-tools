CREATE OR REPLACE PACKAGE BODY "MSG_AQ_PKG" AS

-- private stuff

c_schema constant all_objects.owner%type := $$PLSQL_UNIT_OWNER;

function visibility_descr
( p_visibility in binary_integer
)
return varchar2
is
begin
  return case p_visibility
           when dbms_aq.on_commit then 'ON_COMMIT'
           when dbms_aq.immediate then 'IMMEDIATE'
           else 'UNKNOWN visibility (' || to_char(p_visibility) || ')'
         end;
end visibility_descr;

function delivery_mode_descr
( p_delivery_mode in binary_integer
)
return varchar2
is
begin
  return case p_delivery_mode
           when dbms_aq.persistent then 'PERSISTENT'
           when dbms_aq.buffered then 'BUFFERED'
           when dbms_aq.persistent_or_buffered then 'PERSISTENT_OR_BUFFERED'
           else 'UNKNOWN delivey mode (' || to_char(p_delivery_mode) || ')'
         end;
end delivery_mode_descr;

function dequeue_mode_descr
( p_dequeue_mode in binary_integer
)
return varchar2
is
begin
  return case p_dequeue_mode
           when dbms_aq.browse then 'BROWSE'
           when dbms_aq.locked then 'LOCKED'
           when dbms_aq.remove then 'REMOVE'
           when dbms_aq.remove_nodata then 'REMOVE_NODATA'
           else 'UNKNOWN dequeue mode (' || to_char(p_dequeue_mode) || ')'
         end;
end dequeue_mode_descr;

function navigation_descr
( p_navigation in binary_integer
)
return varchar2
is
begin
  return case p_navigation
           when dbms_aq.next_message then 'NEXT_MESSAGE'
           when dbms_aq.next_transaction then 'NEXT_TRANSACTION'
           when dbms_aq.first_message then 'FIRST_MESSAGE'
           when dbms_aq.first_message_multi_group then 'FIRST_MESSAGE_MULTI_GROUP'
           when dbms_aq.next_message_multi_group then 'NEXT_MESSAGE_MULTI_GROUP'
           else 'UNKNOWN navigation (' || to_char(p_navigation) || ')'
         end;
end navigation_descr;

function state_descr
( p_state in binary_integer
)
return varchar2
is
begin
  return case p_state
           when dbms_aq.ready then 'READY'
           when dbms_aq.waiting then 'WAITING'
           when dbms_aq.processed then 'PROCESSED'
           when dbms_aq.expired then 'EXPIRED'
           else 'UNKNOWN state (' || to_char(p_state) || ')'
         end;
end state_descr;

function sql_object_name
( p_schema in varchar2
, p_object_name in varchar2
)
return varchar2
is
begin
  return p_schema || '.' || p_object_name;
end sql_object_name;

procedure create_queue_at
( p_queue_name in varchar2
, p_comment in varchar2
)
is
  pragma autonomous_transaction;
begin
  create_queue
  ( p_queue_name => p_queue_name
  , p_comment => p_comment
  );
  commit;
end create_queue_at;

procedure start_queue_at
( p_queue_name in varchar2
)
is
  pragma autonomous_transaction;
begin
  start_queue
  ( p_queue_name => p_queue_name
  );
  commit;
end start_queue_at;

$if msg_aq_pkg.c_multiple_consumers $then

procedure add_subscriber_at
( p_queue_name in varchar2
, p_subscriber in varchar2 default c_default_subscriber
, p_rule in varchar2 default null
, p_delivery_mode in binary_integer default c_subscriber_delivery_mode
)
is
  pragma autonomous_transaction;
begin
  add_subscriber
  ( p_queue_name => p_queue_name
  , p_subscriber => p_subscriber
  , p_rule => p_rule
  , p_delivery_mode => p_delivery_mode
  );
  commit;
end add_subscriber_at;  

$end

procedure register_at
( p_queue_name in varchar2
, p_subscriber in varchar2 default c_default_subscriber -- the name of the subscriber already added via add_subscriber (for multi-consumer queues only)
, p_plsql_callback in varchar -- schema.procedure
)
is
  pragma autonomous_transaction;
begin
  register
  ( p_queue_name => p_queue_name
  , p_subscriber => p_subscriber
  , p_plsql_callback => p_plsql_callback
  );
  commit;
end register_at;  

-- public routines

function queue_name
( p_msg in msg_typ
)
return varchar2
is
begin
  return oracle_tools.data_api_pkg.dbms_assert$enquote_name(replace(p_msg.group$, '.', '$'), 'queue');
end queue_name;

procedure create_queue_table
is
begin
$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.enter($$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.CREATE_QUEUE_TABLE');
$end

  dbms_aqadm.create_queue_table
  ( queue_table => c_queue_table
  , queue_payload_type => sql_object_name(c_schema, 'MSG_TYP')
--, storage_clause       IN      VARCHAR2        DEFAULT NULL
--, sort_list            IN      VARCHAR2        DEFAULT NULL
  , multiple_consumers => c_multiple_consumers
  , message_grouping => dbms_aqadm.none
  , comment => 'Queue table containing messages'
--, auto_commit          IN      BOOLEAN         DEFAULT TRUE
--, primary_instance     IN      BINARY_INTEGER  DEFAULT 0
--, secondary_instance   IN      BINARY_INTEGER  DEFAULT 0
--, compatible           IN      VARCHAR2        DEFAULT NULL
--, secure               IN      BOOLEAN         DEFAULT FALSE
--, replication_mode     IN      BINARY_INTEGER  DEFAULT NONE
  );

$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.leave;
$end
end create_queue_table;

procedure drop_queue_table
( p_force in boolean
)
is
begin
$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.enter($$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.DROP_QUEUE_TABLE');
  dbug.print(dbug."input", 'p_force: %s', dbug.cast_to_varchar2(p_force));
$end

  if p_force
  then
    for rq in
    ( select  q.name as queue_name
      from    all_queues q
      where   q.owner = trim('"' from c_schema)
      and     q.queue_table = trim('"' from c_queue_table)
      and     'NO' in ( trim(q.enqueue_enabled), trim(q.dequeue_enabled) )
    )
    loop
      for rsr in
      ( select  location_name
        from    user_subscr_registrations sr
        where   sr.subscription_name = c_schema || '.' || oracle_tools.data_api_pkg.dbms_assert$enquote_name(rq.queue_name, 'queue')
      )
      loop
        unregister
        ( p_queue_name => rq.queue_name
        , p_plsql_callback => rsr.location_name
        );
      end loop;
/*      
      if c_multiple_consumers
      then
        remove_subscriber
        ( p_queue_name => rq.queue_name
        );
      end if;
*/      
      drop_queue
      ( p_queue_name => rq.queue_name
      , p_force => p_force
      );
    end loop;
  end if;

  dbms_aqadm.drop_queue_table
  ( queue_table => c_queue_table
  , force => p_force
  );

$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.leave;
$end
end drop_queue_table;

procedure create_queue
( p_queue_name in varchar2
, p_comment in varchar2
)
is
  l_queue_name constant all_queues.name%type := oracle_tools.data_api_pkg.dbms_assert$simple_sql_name(p_queue_name, 'queue');
begin
$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.enter($$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.CREATE_QUEUE');
  dbug.print(dbug."input", 'p_queue_name: %s; p_comment: %s', p_queue_name, p_comment);
$end

  <<try_loop>>
  for i_try in 1..2
  loop
    begin
      dbms_aqadm.create_queue
      ( queue_name => l_queue_name
      , queue_table => c_queue_table
      , queue_type => dbms_aqadm.normal_queue
      , max_retries => 0 -- no retries
      , retry_delay => 0
      , retention_time => 0
      , comment => p_comment
      );
      exit try_loop;
    exception
      when e_queue_table_does_not_exist
      then
        if i_try = 1
        then
          create_queue_table;
        else
          raise;
        end if;      
    end;
  end loop try_loop;

  start_queue
  ( p_queue_name => p_queue_name
  );

$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.leave;
$end
end create_queue;

procedure drop_queue
( p_queue_name in varchar2
, p_force in boolean
)
is
  l_queue_name constant all_queues.name%type := oracle_tools.data_api_pkg.dbms_assert$simple_sql_name(p_queue_name, 'queue');
begin
$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.enter($$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.DROP_QUEUE');
  dbug.print
  ( dbug."input"
  , 'p_queue_name: %s; p_force: %s'
  , p_queue_name
  , dbug.cast_to_varchar2(p_force)
  );
$end

  if p_force
  then
    stop_queue
    ( p_queue_name => p_queue_name
    , p_wait => true
    );
  end if;

  dbms_aqadm.drop_queue
  ( queue_name => l_queue_name
  );

$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.leave;
$end
end drop_queue;

procedure start_queue
( p_queue_name in varchar2
)
is
  l_queue_name constant all_queues.name%type := oracle_tools.data_api_pkg.dbms_assert$simple_sql_name(p_queue_name, 'queue');
begin
$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.enter($$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.START_QUEUE');
  dbug.print(dbug."input", 'p_queue_name: %s', p_queue_name);
$end

  dbms_aqadm.start_queue
  ( queue_name => l_queue_name
  , enqueue => true
  , dequeue => true
  );

$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.leave;
$end
end start_queue;

procedure stop_queue
( p_queue_name in varchar2
, p_wait in boolean
)
is
  l_queue_name constant all_queues.name%type := oracle_tools.data_api_pkg.dbms_assert$simple_sql_name(p_queue_name, 'queue');
begin
$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.enter($$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.STOP_QUEUE');
  dbug.print
  ( dbug."input"
  , 'p_queue_name: %s; p_waits: %s'
  , p_queue_name
  , dbug.cast_to_varchar2(p_wait)
  );
$end

  dbms_aqadm.stop_queue
  ( queue_name => l_queue_name
  , enqueue => true
  , dequeue => true
  , wait => p_wait
  );

$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.leave;
$end
end stop_queue;

procedure add_subscriber
( p_queue_name in varchar2
, p_subscriber in varchar2
, p_rule in varchar2
, p_delivery_mode in binary_integer
)
is
  l_queue_name constant all_queues.name%type := oracle_tools.data_api_pkg.dbms_assert$simple_sql_name(p_queue_name, 'queue');
begin
$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.enter($$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.ADD_SUBSCRIBER');
  dbug.print
  ( dbug."input"
  , 'p_queue_name: %s; p_subscriber: %s; p_rule: %s; p_delivery_mode: %s'
  , p_queue_name
  , p_subscriber
  , p_rule
  , delivery_mode_descr(p_delivery_mode)
  );
$end

  dbms_aqadm.add_subscriber
  ( queue_name => l_queue_name
  , subscriber => sys.aq$_agent(p_subscriber, null, null)
  , rule => p_rule
  , delivery_mode => p_delivery_mode
  );
  
$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.leave;
$end
end add_subscriber;

procedure remove_subscriber
( p_queue_name in varchar2
, p_subscriber in varchar2
)
is
  l_queue_name constant all_queues.name%type := oracle_tools.data_api_pkg.dbms_assert$simple_sql_name(p_queue_name, 'queue');
begin
$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.enter($$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.REMOVE_SUBSCRIBER');
  dbug.print
  ( dbug."input"
  , 'p_queue_name: %s; p_subscriber: %s'
  , p_queue_name
  , p_subscriber
  );
$end

  dbms_aqadm.remove_subscriber
  ( queue_name => l_queue_name
  , subscriber => sys.aq$_agent(p_subscriber, null, null)
  );
  
$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.leave;
$end
end remove_subscriber;

procedure register
( p_queue_name in varchar2
, p_subscriber in varchar2
, p_plsql_callback in varchar
)
is
  l_queue_name constant all_queues.name%type := oracle_tools.data_api_pkg.dbms_assert$simple_sql_name(p_queue_name, 'queue');
begin
$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.enter($$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.REGISTER');
  dbug.print
  ( dbug."input"
  , 'p_queue_name: %s; p_subscriber: %s; p_plsql_callback: %s'
  , p_queue_name
  , p_subscriber
  , p_plsql_callback
  );
$end

  dbms_aq.register
  ( reg_list => sys.aq$_reg_info_list
                ( sys.aq$_reg_info
                  ( name => sql_object_name(c_schema, l_queue_name) || case when p_subscriber is not null then ':' || p_subscriber end
                  , namespace => dbms_aq.namespace_aq
                  , callback => 'plsql://' || p_plsql_callback
                  , context => hextoraw('FF')
                  )
                )
  , reg_count => 1
  );

$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.leave;
$end
end register;

procedure unregister
( p_queue_name in varchar2
, p_subscriber in varchar2
, p_plsql_callback in varchar
)
is
  l_queue_name constant all_queues.name%type := oracle_tools.data_api_pkg.dbms_assert$simple_sql_name(p_queue_name, 'queue');
begin
$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.enter($$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.UNREGISTER');
  dbug.print
  ( dbug."input"
  , 'p_queue_name: %s; p_subscriber: %s; p_plsql_callback: %s'
  , p_queue_name
  , p_subscriber
  , p_plsql_callback
  );
$end

  dbms_aq.unregister
  ( reg_list => sys.aq$_reg_info_list
                ( sys.aq$_reg_info
                  ( name => sql_object_name(c_schema, l_queue_name) || case when p_subscriber is not null then ':' || p_subscriber end
                  , namespace => dbms_aq.namespace_aq
                  , callback => 'plsql://' || p_plsql_callback
                  , context => hextoraw('FF')
                  )
                )
  , reg_count => 1
  );

$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.leave;
$end
end unregister;

procedure enqueue
( p_msg in msg_typ
, p_delivery_mode in binary_integer
, p_visibility in binary_integer
, p_force in boolean
, p_msgid out nocopy raw
)
is
  l_queue_name constant user_queues.name%type := queue_name(p_msg);
  l_enqueue_enabled user_queues.enqueue_enabled%type;
  l_dequeue_enabled user_queues.dequeue_enabled%type;
  l_enqueue_options dbms_aq.enqueue_options_t;
  l_message_properties dbms_aq.message_properties_t;
  c_max_tries constant simple_integer := case when p_force then 2 else 1 end;
begin
$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.enter($$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.ENQUEUE');
  dbug.print
  ( dbug."input"  
  , 'p_delivery_mode: %s; p_visibility: %s; p_force: %s'
  , delivery_mode_descr(p_delivery_mode)
  , visibility_descr(p_visibility)  
  , dbug.cast_to_varchar2(p_force)
  );
$end

  if ( p_delivery_mode = dbms_aq.persistent and p_visibility = dbms_aq.on_commit ) or
     ( p_delivery_mode = dbms_aq.buffered   and p_visibility = dbms_aq.immediate ) or
     ( p_delivery_mode = dbms_aq.persistent and p_visibility = dbms_aq.immediate )
  then 
    l_enqueue_options.delivery_mode := p_delivery_mode;
    l_enqueue_options.visibility := p_visibility;
  else
    if p_msg.has_not_null_lob() != 0
    then
      -- payload with a non-empty LOB can not be a buffered message
      l_enqueue_options.delivery_mode := dbms_aq.persistent;
      l_enqueue_options.visibility := dbms_aq.on_commit;
    else
      -- prefer buffered messages
      l_enqueue_options.delivery_mode := dbms_aq.buffered;
      l_enqueue_options.visibility := dbms_aq.immediate;
    end if;

    -- give a warning when the input parameters were not default and not a correct combination

$if oracle_tools.cfg_pkg.c_debugging $then
    if ( p_delivery_mode is not null or p_visibility is not null )
    then
      dbug.print
      ( dbug."warning"
      , 'delivery mode: %s => %s; visibility: %s => %s'
      , delivery_mode_descr(p_delivery_mode)
      , delivery_mode_descr(l_enqueue_options.delivery_mode)
      , visibility_descr(p_visibility)
      , visibility_descr(l_enqueue_options.visibility)
      );
    end if;
$end

  end if;

  l_message_properties.delay := dbms_aq.no_delay;

$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.print
  ( dbug."info"
  , 'l_enqueue_options.visibility: %s; l_enqueue_options.delivery_mode: %s; l_message_properties.delay: %s'
  , visibility_descr(l_enqueue_options.visibility)
  , delivery_mode_descr(l_enqueue_options.delivery_mode)
  , l_message_properties.delay
  );
$end

  l_message_properties.expiration := dbms_aq.never;

  <<try_loop>>
  for i_try in 1 .. c_max_tries
  loop
    begin
      dbms_aq.enqueue
      ( queue_name => l_queue_name
      , enqueue_options => l_enqueue_options
      , message_properties => l_message_properties
      , payload => p_msg
      , msgid => p_msgid
      );
      exit try_loop; -- enqueue succeeded
    exception
      when e_queue_does_not_exist
      then
        if i_try != c_max_tries
        then
          create_queue_at
          ( p_queue_name => l_queue_name
          , p_comment => 'Queue for table ' || replace(l_queue_name, '$', '.')
          );
$if msg_aq_pkg.c_multiple_consumers $then
          add_subscriber_at
          ( p_queue_name => l_queue_name
          );
$end
          register_at
          ( p_queue_name => l_queue_name
          , p_plsql_callback => c_default_plsql_callback
          );
        else
          raise;
        end if;
      when e_enqueue_disabled
      then
        if i_try != c_max_tries
        then
          start_queue_at
          ( p_queue_name => l_queue_name
          );
        else
          raise;
        end if;
      when others
      then raise;
    end;
  end loop try_loop;  

$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.print(dbug."output", 'p_msgid: %s', rawtohex(p_msgid));
  dbug.leave;
exception
  when others
  then
    dbug.leave_on_error;
    raise;
$end
end enqueue;

procedure dequeue
( p_queue_name in varchar2 -- Can be fully qualified (including schema).
, p_delivery_mode in binary_integer
, p_visibility in binary_integer
, p_subscriber in varchar2
, p_dequeue_mode in binary_integer
, p_navigation in binary_integer
, p_wait in binary_integer
, p_deq_condition in varchar2
, p_msgid in out nocopy raw
, p_message_properties out nocopy dbms_aq.message_properties_t
, p_msg out nocopy msg_typ
)
is
  l_queue_name constant user_queues.name%type := nvl(p_queue_name, queue_name(p_msg));
  l_dequeue_options dbms_aq.dequeue_options_t;
begin
$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.enter($$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.DEQUEUE');
  dbug.print
  ( dbug."input"
  , 'p_queue_name: %s; p_delivery_mode: %s; p_visibility: %s; p_subscriber: %s; p_dequeue_mode: %s'
  , p_queue_name
  , delivery_mode_descr(p_delivery_mode)
  , visibility_descr(p_visibility)
  , p_subscriber
  , dequeue_mode_descr(p_dequeue_mode)
  );
  dbug.print
  ( dbug."input"
  , 'p_navigation: %s; p_wait: %s; p_deq_condition: %s; p_msgid: %s'
  , navigation_descr(p_navigation)
  , p_wait
  , p_deq_condition
  , hextoraw(p_msgid)
  );
$end

  l_dequeue_options.consumer_name := p_subscriber;
  l_dequeue_options.dequeue_mode := p_dequeue_mode;
  l_dequeue_options.navigation := p_navigation;
  l_dequeue_options.wait := p_wait;
  l_dequeue_options.deq_condition := p_deq_condition;
  l_dequeue_options.msgid := p_msgid;

  if ( p_delivery_mode = dbms_aq.persistent and p_visibility = dbms_aq.on_commit ) or
     ( p_delivery_mode = dbms_aq.buffered   and p_visibility = dbms_aq.immediate ) or
     ( p_delivery_mode = dbms_aq.persistent and p_visibility = dbms_aq.immediate )
  then 
    l_dequeue_options.delivery_mode := p_delivery_mode;
    l_dequeue_options.visibility := p_visibility;
  else
    -- Visibility must always be IMMEDIATE when dequeuing messages with delivery mode DBMS_AQ.BUFFERED
    case
      -- try to preserve at least one of the input settings
      when p_delivery_mode = dbms_aq.buffered
      then
        l_dequeue_options.delivery_mode := p_delivery_mode;
        l_dequeue_options.visibility := dbms_aq.immediate;
        
      when p_visibility = dbms_aq.on_commit
      then
        l_dequeue_options.delivery_mode := dbms_aq.persistent;
        l_dequeue_options.visibility := p_visibility;
      
      else
        l_dequeue_options.delivery_mode := dbms_aq.persistent;
        l_dequeue_options.visibility := dbms_aq.on_commit;
    end case;

    -- give a warning when the input parameters were not default and not a correct combination

$if oracle_tools.cfg_pkg.c_debugging $then
    if ( p_delivery_mode is not null or p_visibility is not null )
    then
      dbug.print
      ( dbug."warning"
      , 'delivery mode: %s => %s; visibility: %s => %s'
      , delivery_mode_descr(p_delivery_mode)
      , delivery_mode_descr(l_dequeue_options.delivery_mode)
      , visibility_descr(p_visibility)
      , visibility_descr(l_dequeue_options.visibility)
      );
    end if;
$end
  end if;  

$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.print
  ( dbug."info"
  , 'l_dequeue_options.visibility: %s; l_dequeue_options.delivery_mode: %s'
  , visibility_descr(l_dequeue_options.visibility)
  , delivery_mode_descr(l_dequeue_options.delivery_mode)
  );
$end

  dbms_aq.dequeue
  ( queue_name => l_queue_name
  , dequeue_options => l_dequeue_options
  , message_properties => p_message_properties
  , payload => p_msg
  , msgid => p_msgid
  );

$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.print(dbug."output", 'p_msgid: %s', rawtohex(p_msgid));
  dbug.leave;
$end
end dequeue;

procedure dequeue_and_process
( p_queue_name in varchar2 -- Can be fully qualified (including schema).
, p_delivery_mode in binary_integer
, p_visibility in binary_integer
, p_subscriber in varchar2
, p_dequeue_mode in binary_integer
, p_navigation in binary_integer
, p_wait in binary_integer
, p_deq_condition in varchar2
, p_commit in boolean
)
is
  l_msgid raw(16) := null;
  l_message_properties dbms_aq.message_properties_t;
  l_msg msg_typ;
begin
$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.enter($$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.DEQUEUE_AND_PROCESS');
  dbug.print(dbug."input", 'p_commit: %s', p_commit);
$end

  dequeue
  ( p_queue_name => p_queue_name
  , p_delivery_mode => p_delivery_mode
  , p_visibility => p_visibility
  , p_subscriber => p_subscriber
  , p_dequeue_mode => p_dequeue_mode
  , p_navigation => p_navigation
  , p_wait => p_wait
  , p_deq_condition => p_deq_condition
  , p_msgid => l_msgid
  , p_message_properties => l_message_properties
  , p_msg => l_msg
  );

  begin
    savepoint spt;
    
    l_msg.process(p_maybe_later => 0);
  exception
    when others
    then
      rollback to spt;
  end;

  if p_commit
  then
    commit; -- remove message from the queue
  end if;

$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.leave;
$end
end dequeue_and_process;

procedure dequeue
( p_context in raw
, p_reginfo in sys.aq$_reg_info
, p_descr in sys.aq$_descriptor
, p_payload in raw
, p_payloadl in number
, p_msgid out nocopy raw
, p_message_properties out nocopy dbms_aq.message_properties_t
, p_msg out nocopy msg_typ
)
is
begin
$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.enter($$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.DEQUEUE');
  dbug.print
  ( dbug."input"
  , 'p_context: %s; p_descr.msg_id: %s; p_descr.consumer_name: %s; p_descr.queue_name: %s; p_payloadl: %s'
  , p_context
  , rawtohex(p_descr.msg_id)
  , p_descr.consumer_name
  , p_descr.queue_name
  , p_payloadl
  );
  dbug.print
  ( dbug."input"
  , 'p_descr.msg_prop.state: %s; p_descr.msg_prop.delivery_mode: %s'
  , state_descr(p_descr.msg_prop.state)
  , delivery_mode_descr(p_descr.msg_prop.delivery_mode)
  );
$end

  p_msgid := p_descr.msg_id;

$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.print
  ( dbug."info"
  , 'USERENV: SESSIONID: %s; APEX$SESSION.APP_SESSION|CLIENT_IDENTIFIER: %s; CURRENT_USER: %s; SESSION_USER: %s; PROXY_USER: %s'
  , sys_context('USERENV', 'SESSIONID') ||
      case
        when sys_context('USERENV', 'BG_JOB_ID') is not null
        then ' (BG_JOB_ID=' || sys_context('USERENV', 'BG_JOB_ID') || ')'
        when sys_context('USERENV', 'FG_JOB_ID') is not null
        then ' (FG_JOB_ID=' || sys_context('USERENV', 'FG_JOB_ID') || ')'
      end
  , nvl(sys_context('APEX$SESSION', 'APP_SESSION'), sys_context('USERENV', 'CLIENT_IDENTIFIER'))
  , sys_context('USERENV', 'CURRENT_USER')
  , sys_context('USERENV', 'SESSION_USER')
  , sys_context('USERENV', 'PROXY_USER')
  );
$end

  dequeue
  ( p_queue_name => p_descr.queue_name
  , p_delivery_mode => p_descr.msg_prop.delivery_mode
  , p_visibility =>
      -- to suppress a warning
      case
        when p_descr.msg_prop.delivery_mode in ( dbms_aq.buffered, dbms_aq.persistent_or_buffered )
        then dbms_aq.immediate
        else dbms_aq.on_commit
      end
  , p_subscriber => p_descr.consumer_name 
  , p_dequeue_mode => dbms_aq.remove
  , p_navigation => dbms_aq.next_message
  , p_wait => dbms_aq.no_wait -- message is there
  , p_deq_condition => null
  , p_msgid => p_msgid
  , p_message_properties => p_message_properties
  , p_msg => p_msg
  );

$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.print(dbug."output", 'p_msgid: %s', rawtohex(p_msgid));
  dbug.leave;
$end
end dequeue;

procedure dequeue_and_process
( p_context in raw
, p_reginfo in sys.aq$_reg_info
, p_descr in sys.aq$_descriptor
, p_payload in raw
, p_payloadl in number
, p_commit in boolean
)
is
  l_msgid raw(16);
  l_message_properties dbms_aq.message_properties_t;
  l_msg msg_typ;
begin
$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.enter($$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.DEQUEUE_AND_PROCESS');
  dbug.print(dbug."input", 'p_commit: %s', p_commit);
$end

  msg_aq_pkg.dequeue
  ( p_context => p_context
  , p_reginfo => p_reginfo
  , p_descr => p_descr
  , p_payload => p_payload
  , p_payloadl => p_payloadl
  , p_msgid => l_msgid
  , p_message_properties => l_message_properties
  , p_msg => l_msg
  );

  begin
    savepoint spt;
    
    l_msg.process(p_maybe_later => 0);
  exception
    when others
    then
      rollback to spt;
  end;

  if p_commit
  then
    commit; -- remove message from the queue
  end if;

$if oracle_tools.cfg_pkg.c_debugging $then
  dbug.leave;
exception
  when others
  then
    dbug.leave_on_error;
    raise;
$end
end dequeue_and_process;

$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.cfg_pkg.c_testing $then

procedure ut_rest_web_service_sync
is
  procedure chk_dbug_dbms_output
  is
    l_lines_exp constant sys.odcivarchar2list :=
      sys.odcivarchar2list
      ( '>ORACLE_TOOLS.MSG_TYP.PROCESS'
      , '|   input: p_maybe_later: 0'
      , '|   >ORACLE_TOOLS.REST_WEB_SERVICE_TYP.PROCESS (1)'
      , '|   |   output: p_clob length: 83; contents (max 255 characters): "{'
      , '  "userId": 1,'
      , '  "id": 1,'
      , '  "title": "delectus aut autem",'
      , '  "completed": false'
      , '}"'
      , '|   <ORACLE_TOOLS.REST_WEB_SERVICE_TYP.PROCESS (1)'
      , '<ORACLE_TOOLS.MSG_TYP.PROCESS'
      );
    l_lines_act dbms_output.chararr;
    l_numlines integer := l_lines_exp.count; -- the number of lines to retrieve
  begin
    dbms_output.get_lines(lines => l_lines_act, numlines => l_numlines);
    ut.expect(l_numlines, '# lines').to_equal(l_lines_exp.count);
    ut.expect(l_lines_act.first, 'lines first').to_equal(l_lines_exp.first);
    for i_idx in l_lines_exp.first .. l_lines_exp.last
    loop
      ut.expect(case when l_lines_act.exists(i_idx) then l_lines_act(i_idx) end, to_char(i_idx)).to_equal(l_lines_exp(i_idx));
    end loop;
    /*
    for i_idx in l_lines_exp.first .. l_lines_exp.last
    loop
      dbms_output.put_line(l_lines_exp(i_idx));
    end loop;
    */
  end chk_dbug_dbms_output;
begin
  -- See https://terminalcheatsheet.com/guides/curl-rest-api

  -- % curl https://jsonplaceholder.typicode.com/todos/1
  --
  -- {
  --   "userId": 1,
  --   "id": 1,
  --   "title": "delectus aut autem",
  --   "completed": false
  -- }%                                                                                                                                                                                                           

  -- This will run it right now and use dbug_dbms_output, i.e. dbms_output
  dbms_output.disable; -- clear the buffer
  dbms_output.enable;
  dbug.activate('dbms_output');

  rest_web_service_typ
  ( p_group$ => 'REST_WEB_SERVICE'
  , p_context$ => null
  , p_url => 'https://jsonplaceholder.typicode.com/todos/1'
  , p_http_method => 'GET'
  ).process(p_maybe_later => 0);

  chk_dbug_dbms_output;
end ut_rest_web_service_sync;

procedure ut_rest_web_service_async
is
  pragma autonomous_transaction;

  l_start constant date := sysdate;

  -- ORA-06550: line 1, column 7:
  -- PLS-00201: identifier 'PLOG.PURGE' must be declared
  e_compilation_error exception;
  pragma exception_init(e_compilation_error, -06550);    

  -- ORA-00942: table or view does not exist
  e_object_does_not_exist exception;
  pragma exception_init(e_object_does_not_exist, -00942);

  procedure chk_dbug_log4plsql
  is
    l_lines_exp constant sys.odcivarchar2list :=
      sys.odcivarchar2list
      ( '>ORACLE_TOOLS.MSG_NOTIFICATION_PRC'
      , '|   >ORACLE_TOOLS.MSG_AQ_PKG.DEQUEUE_AND_PROCESS'
      , '|   |   input: p_commit: TRUE'
      , '|   |   >ORACLE_TOOLS.MSG_AQ_PKG.DEQUEUE'
      , '|   |   |   input: p_context: FF; p_descr.msg_id: 05; p_descr.consumer_name: <NULL>; p_descr.queue_name: "ORACLE_TOOLS"."REST_WEB_SERVICE"; p_payloadl: 0'
      , '|   |   |   input: p_descr.msg_prop.state: READY; p_descr.msg_prop.delivery_mode: BUFFERED'
      , '|   |   |   info: USERENV: SESSIONID: 1067696434 (BG_JOB_ID=77142); APEX$SESSION.APP_SESSION|CLIENT_IDENTIFIER: <NULL>; CURRENT_USER: ORACLE_TOOLS; SESSION_USER: SYS; PROXY_USER: <NULL>'
      , '|   |   |   >ORACLE_TOOLS.MSG_AQ_PKG.DEQUEUE'
      , '|   |   |   |   input: p_queue_name: "ORACLE_TOOLS"."REST_WEB_SERVICE"; p_delivery_mode: BUFFERED; p_visibility: IMMEDIATE; p_subscriber: <NULL>; p_dequeue_mode: REMOVE'
      , '|   |   |   |   input: p_navigation: NEXT_MESSAGE; p_wait: 0; p_deq_condition: <NULL>; p_msgid: 05'
      , '|   |   |   |   info: l_dequeue_options.visibility: IMMEDIATE; l_dequeue_options.delivery_mode: BUFFERED'
      , '|   |   |   |   output: p_msgid: 05'
      , '|   |   |   <ORACLE_TOOLS.MSG_AQ_PKG.DEQUEUE'
      , '|   |   |   output: p_msgid: 05'
      , '|   |   <ORACLE_TOOLS.MSG_AQ_PKG.DEQUEUE'
      , '|   |   >ORACLE_TOOLS.MSG_TYP.PROCESS'
      , '|   |   |   input: p_maybe_later: 0'
      , '|   |   |   >ORACLE_TOOLS.REST_WEB_SERVICE_TYP.PROCESS (1)'
      , '|   |   |   |   output: p_clob length: 15; contents (max 255 characters): "{'
      , '  "id": 101'
      , '}"'
      , '|   |   |   <ORACLE_TOOLS.REST_WEB_SERVICE_TYP.PROCESS (1)'
      , '|   |   <ORACLE_TOOLS.MSG_TYP.PROCESS'
      , '|   <ORACLE_TOOLS.MSG_AQ_PKG.DEQUEUE_AND_PROCESS'
      , '<ORACLE_TOOLS.MSG_NOTIFICATION_PRC'
      );
    l_lines_act dbms_output.chararr;
    l_numlines integer := l_lines_exp.count; -- the number of lines to retrieve
    l_cursor sys_refcursor;
    l_check boolean := false;
  begin
    open l_cursor for q'[select ltext from tlog where luser = 'SYS' and ldate >= :1 order by id]' using l_start;
    fetch l_cursor bulk collect into l_lines_act;
    close l_cursor;
    
    ut.expect(l_numlines, '# lines').to_equal(l_lines_exp.count);
    ut.expect(l_lines_act.first, 'lines first').to_equal(l_lines_exp.first);
    for i_idx in l_lines_exp.first .. l_lines_exp.last
    loop
      if l_lines_act.exists(i_idx)
      then
        if l_lines_act(i_idx) like '%>ORACLE_TOOLS.MSG_TYP.PROCESS'
        then
          l_check := true;
        end if;
        
        if l_check
        then
          ut.expect(l_lines_act(i_idx), to_char(i_idx)).to_equal(l_lines_exp(i_idx));
        end if;
        
        if l_lines_act(i_idx) like '%<ORACLE_TOOLS.MSG_TYP.PROCESS'
        then
          l_check := false;
        end if;
      end if;
    end loop;
  end chk_dbug_log4plsql;
begin
  -- See https://terminalcheatsheet.com/guides/curl-rest-api

  -- This will run it asynchronous issue and use dbug_log4plsql, i.e. plog / tlog.
  -- But these objects may not be granted (or having no synoyms) so use dynamic PL/SQL.
  dbug.activate('log4plsql');

  rest_web_service_typ
  ( p_group$ => 'REST_WEB_SERVICE'
  , p_context$ => null
  , p_url => 'https://jsonplaceholder.typicode.com/posts'
  , p_http_method => 'POST'
  , p_body_clob => to_clob('{"title":"foo","body":"bar","userId":123}')
  ).process;

  commit; -- otherwise it may never arrive in the queue

  chk_dbug_log4plsql;

  commit;
exception
  when e_compilation_error or e_object_does_not_exist
  then commit;
end ut_rest_web_service_async;

$end -- $if oracle_tools.cfg_pkg.c_debugging and oracle_tools.cfg_pkg.c_testing $then

end msg_aq_pkg;
/

