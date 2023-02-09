CREATE TYPE "REST_WEB_SERVICE_TYP" under msg_typ
( -- Attributes are derived from apex_web_service.make_rest_request().
  -- However, no sensitive information like username or password is stored.
  url varchar2(2000 char)
, http_method varchar2(10 byte)
, scheme varchar2(100 char)
, proxy_override varchar2(2000 char)
, transfer_timeout number
, body_vc varchar2(4000 byte)
, body_clob clob
, body_raw raw(2000)
, body_blob blob
  -- parms_vc/parms_clob: json object with parameter name/value pairs like in apex_web_service.make_rest_request(..., parm_name, parm_value, ...)
, parms_vc varchar2(4000 byte)
, parms_clob clob
, wallet_path varchar2(2000 char)
, https_host varchar2(2000 char)
, credential_static_id varchar2(100 char)
, token_url varchar2(2000 char)
/**

This type allows you to make a REST web service call, either synchronous or asynchronous.

The Oracle AQ documentation states this about enqueuing buffered messages: the
queue type for buffered messaging can be ADT, XML, ANYDATA, or RAW. For ADT
types with LOB attributes, only buffered messages with null LOB attributes can
be enqueued.

Since we want to be able to enqueue buffered messages we must take care of the
LOBs above. There are two variants: a small variant with suffix _vc/_raw or
otherwise the LOB variant with suffix _clob/_blob (meaning we can not use
buffered messages if it has length > 0).

The procedures you usually should use are:
* ws = new rest_web_service_typ()
* ws.process(p_maybe_later)
* ws.process(p_clob) if you want to do a synchronous call right now with text output (but ws.process$now does the same without returning the output)
* ws.process(p_blob) if you want to do a synchronous call right now with binary output

**/
, constructor function rest_web_service_typ
  ( self in out nocopy rest_web_service_typ
  , p_group$ in varchar2
  , p_context$ in varchar2
  , p_url in varchar2
  , p_http_method in varchar2
  , p_scheme in varchar2 default 'Basic'
  , p_proxy_override in varchar2 default null
  , p_transfer_timeout in number default 180
  , p_body_clob in clob default null
  , p_body_blob in blob default null
  , p_parms_clob in clob default null
  , p_wallet_path in varchar2 default null
  , p_https_host in varchar2 default null
  , p_credential_static_id in varchar2 default null
  , p_token_url in varchar2 default null
  )
  return self as result

, final member procedure construct
  ( self in out nocopy rest_web_service_typ
  , p_group$ in varchar2
  , p_context$ in varchar2
  , p_url in varchar2
  , p_http_method in varchar2
  , p_scheme in varchar2 default 'Basic'
  , p_proxy_override in varchar2 default null
  , p_transfer_timeout in number default 180
  , p_body_clob in clob default null
  , p_body_blob in blob default null
  , p_parms_clob in clob default null
  , p_wallet_path in varchar2 default null
  , p_https_host in varchar2 default null
  , p_credential_static_id in varchar2 default null
  , p_token_url in varchar2 default null
  )

, overriding
  member function must_be_processed
  ( self in rest_web_service_typ
  , p_maybe_later in integer -- True (1) or false (0)
  )
  return integer -- True (1) or false (0)

, overriding
  member procedure process$now
  ( self in rest_web_service_typ
  )
/** Invokes self.process(p_clob) **/

, overriding
  member procedure serialize
  ( self in rest_web_service_typ
  , p_json_object in out nocopy json_object_t
  )

, overriding
  member function has_not_null_lob
  ( self in rest_web_service_typ
  )
  return integer

, member procedure process_preamble
  ( self in rest_web_service_typ
  )
/** Things to do before the request. Currently nothing. **/

, member procedure process
  ( self in rest_web_service_typ
  , p_username in varchar2 default null -- The username if basic authentication is required for this service
  , p_password in varchar2 default null -- The password if basic authentication is required for this service
  , p_wallet_pwd in varchar2 default null -- You can also use the auto login option for wallets
  , p_clob out nocopy clob
  )
/**

Invokes:
1. self.process_preamble()
2. apex_web_service.make_rest_request()
3. self.process_postamble()

**/

, member procedure process
  ( self in rest_web_service_typ
  , p_username in varchar2 default null -- The username if basic authentication is required for this service
  , p_password in varchar2 default null -- The password if basic authentication is required for this service
  , p_wallet_pwd in varchar2 default null -- You can also use the auto login option for wallets
  , p_blob out nocopy blob
  )
/**

Invokes:
1. self.process_preamble()
2. apex_web_service.make_rest_request()
3. self.process_postamble()

**/

, member procedure process_postamble
  ( self in rest_web_service_typ
  )
/** Things to do after the request. Currently nothing. **/

);
/

