CREATE OR REPLACE PACKAGE "MSG_AQ_PKG" AUTHID DEFINER AS 

c_queue_table constant user_queues.queue_table%type := '"MSG_QT"';
c_multiple_consumers constant boolean := false; -- single consumer is the fastest option
c_default_subscriber constant varchar2(30 char) := case when c_multiple_consumers then 'DEFAULT_SUBSCRIBER' end;
c_default_plsql_callback constant varchar(128 char) := $$PLSQL_UNIT_OWNER || '.' || 'MSG_NOTIFICATION_PRC';
c_subscriber_delivery_mode constant binary_integer := dbms_aqadm.persistent_or_buffered;

-- ORA-24002: QUEUE_TABLE does not exist
e_queue_table_does_not_exist exception;
pragma exception_init(e_queue_table_does_not_exist, -24002);

-- ORA-24010: QUEUE does not exist
e_queue_does_not_exist exception;
pragma exception_init(e_queue_does_not_exist, -24010);

-- ORA-24033: no recipients for message
e_no_recipients_for_message exception;
pragma exception_init(e_no_recipients_for_message, -24033);

-- ORA-25207: enqueue failed, queue is disabled from enqueueing
e_enqueue_disabled exception;
pragma exception_init(e_enqueue_disabled, -25207);

-- ORA-24034: application ... is already a subscriber for queue ...
e_subscriber_already_exists exception;
pragma exception_init(e_subscriber_already_exists, -24034);

-- ORA-24035: AQ agent ... is not a subscriber for queue ...
e_subscriber_does_not_exist exception;
pragma exception_init(e_subscriber_does_not_exist, -24035);

/**

This package is used as a wrapper around Oracle Advanced Queueing.

Its main usage is to enqueue messages (object type MSG_TYP or one of its sub types).

Next they can be dequeued by another process or by asynchronous PL/SQL notifications.

The default functionality is:
- single consumers and PL/SQL notifications
- message delivery is BUFFERED MESSAGES, i.e. storage in memory and not in the tables (not possible if the data contains non-empty LOBs)

**/

function queue_name
( p_msg in msg_typ
)
return varchar2;
/** Returns the enquoted simple SQL queue name, i.e. replace(p_msg.group$, '.', '$') (enquoted via DBMS_ASSERT.ENQUOTE_NAME). **/

procedure create_queue_table;
/** Create the queue table c_queue_table. **/

procedure drop_queue_table
( p_force in boolean default false -- Must we drop queues first?
);
/** Drop the queue table c_queue_table. **/

procedure create_queue
( p_queue_name in varchar2 -- Must be a simple SQL name
, p_comment in varchar2
);
/** Create the queue with queue table c_queue_table. When the queue table does not exist, it is created too. **/

procedure drop_queue
( p_queue_name in varchar2 -- Must be a simple SQL name
, p_force in boolean default false -- Must we stop enqueueing / dequeueing first?
);
/** Drop the queue. Does not drop the queue table. **/

procedure start_queue
( p_queue_name in varchar2 -- Must be a simple SQL name
);
/** Start the queue with enqueue and dequeue enabled. **/

procedure stop_queue
( p_queue_name in varchar2 -- Must be a simple SQL name
, p_wait in boolean default true
);
/** Stop the queue with enqueue and dequeue disabled. **/

procedure add_subscriber
( p_queue_name in varchar2
, p_subscriber in varchar2 default c_default_subscriber
, p_rule in varchar2 default null
, p_delivery_mode in binary_integer default c_subscriber_delivery_mode
);
/** Add a subscriber to a queue. The subscriber name will be ignored for a single consumer queue table. **/
   
procedure remove_subscriber
( p_queue_name in varchar2
, p_subscriber in varchar2 default c_default_subscriber
);
/** Remove a subscriber from a queue. The subscriber name will be ignored for a single consumer queue table. **/

procedure register
( p_queue_name in varchar2
, p_subscriber in varchar2 default c_default_subscriber -- the name of the subscriber already added via add_subscriber (for multi-consumer queues only)
, p_plsql_callback in varchar default c_default_plsql_callback -- In the format schema.procedure
);
/** Register a PL/SQL callback for a queue and subscriber. **/

procedure unregister
( p_queue_name in varchar2
, p_subscriber in varchar2 default c_default_subscriber -- the name of the subscriber already added via add_subscriber (for multi-consumer queues only)
, p_plsql_callback in varchar default c_default_plsql_callback -- In the format schema.procedure
);
/** Unregister a PL/SQL callback for a queue and subscriber. **/

procedure enqueue
( p_msg in msg_typ -- the message
, p_delivery_mode in binary_integer default null -- when null the message payload will determine this
, p_visibility in binary_integer default null -- when null the message payload will determine this
, p_force in boolean default true -- When true, queue tables, queues, subscribers and notifications will be created/added if necessary
, p_msgid out nocopy raw
);
/**

Enqueue the message to the queue queue_name(p_msg).

For AQ there are tree valid combinations for delivery mode and visibility:
1. delivery mode equal to dbms_aq.persistent and visibility equal to dbms_aq.on_commit
2. delivery mode equal to dbms_aq.buffered and visibility equal to dbms_aq.immediate (buffered message)
3. delivery mode equal to dbms_aq.persistent and visibility equal to dbms_aq.immediate

When the input is not one of these combination the message payload will determine one of the first two combinations.
When the message has a not null lob (p_msg.has_not_null_lob() != 0), AQ does not allow visibility to be immediate hence not a buffered message.
So in that case the first combination will be used.
Otherwise, when there is NOT an empty lob, the second combination.

**/

procedure dequeue
( p_queue_name in varchar2 -- Can be fully qualified (including schema).
, p_delivery_mode in binary_integer -- dbms_aq.persistent or dbms_aq.buffered
, p_visibility in binary_integer -- dbms_aq.on_commit (persistent delivery mode only) or dbms_aq.immediate (all delivery modes)
, p_subscriber in varchar2 default c_default_subscriber
, p_dequeue_mode in binary_integer default dbms_aq.remove
, p_navigation in binary_integer default dbms_aq.next_message
, p_wait in binary_integer default dbms_aq.forever
, p_deq_condition in varchar2 default null
, p_msgid in out nocopy raw
, p_message_properties out nocopy dbms_aq.message_properties_t
, p_msg out nocopy msg_typ
);
/**

Dequeue the message (of base type msg_typ) from the queue. The caller must process it (use <message>.process(0)).

For AQ there are tree valid combinations for delivery mode and visibility:
1. delivery mode equal to dbms_aq.persistent and visibility equal to dbms_aq.on_commit
2. delivery mode equal to dbms_aq.buffered and visibility equal to dbms_aq.immediate (buffered message)
3. delivery mode equal to dbms_aq.persistent and visibility equal to dbms_aq.immediate

When the input is not one of these combinations:
* if p_delivery_mode equals dbms_aq.buffered, the visibility will become dbms_aq.immediate
* if p_visibility equals dbms_aq.on_commit, the delivery mode will become dbms_aq.persistent
* otherwise delivery mode will become dbms_aq.persistent and visibility will be dbms_aq.on_commit

**/

procedure dequeue_and_process
( p_queue_name in varchar2 -- Can be fully qualified (including schema).
, p_delivery_mode in binary_integer
, p_visibility in binary_integer
, p_subscriber in varchar2 default c_default_subscriber
, p_dequeue_mode in binary_integer default dbms_aq.remove
, p_navigation in binary_integer default dbms_aq.next_message
, p_wait in binary_integer default dbms_aq.forever
, p_deq_condition in varchar2 default null
, p_commit in boolean default true
);
/** Dequeue a message (of base type msg_typ) from the queue and process it using <message>.process(0). **/

procedure dequeue
( p_context in raw
, p_reginfo in sys.aq$_reg_info
, p_descr in sys.aq$_descriptor
, p_payload in raw
, p_payloadl in number
, p_msgid out nocopy raw
, p_message_properties out nocopy dbms_aq.message_properties_t
, p_msg out nocopy msg_typ
);
/**
Dequeue a message (of base type msg_typ) as a result of a PL/SQL notification. The caller must process it (use <message>.process(0)). 
The first 5 parameters are mandated from the PL/SQL callback definition.

Some notes:
-- The message id to dequeue is p_descr.msg_id
-- The subscriber is p_descr.consumer_name
-- The dequeue mode is dbms_aq.remove
-- The navigation is dbms_aq.next_message
-- The delivery mode p_descr.msg_prop.delivery_mode (dbms_aq.buffered or dbms_aq.persistent)
-- The visibility will be dbms_aq.immediate for delivery mode dbms_aq.buffered, otherwise dbms_aq.on_commit
-- No dequeue condition
-- No wait since the message is supposed to be there
**/

procedure dequeue_and_process
( p_context in raw
, p_reginfo in sys.aq$_reg_info
, p_descr in sys.aq$_descriptor
, p_payload in raw
, p_payloadl in number
, p_commit in boolean default true
);
/**
Dequeue a message (of base type msg_typ) from the queue as a result of a PL/SQL notification and process it using <message>.process(0).
The first 5 parameters are mandated from the PL/SQL callback definition.

See also the dequeue(p_context...) procedure documentation.
**/

end msg_aq_pkg;
/

