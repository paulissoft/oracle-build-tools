CREATE TYPE "DATA_ROW_T" AUTHID CURRENT_USER AS OBJECT
( table_owner varchar2(128 char)
, table_name varchar2(128 char)
, dml_operation varchar2(1 byte) -- (I)nsert/(U)pdate/(D)elete
, key anydata
, dml_timestamp timestamp
/**
This type stores (meta-)information about a data row. It is intented as a generic type that can be used in Oracle Advanced Queueing.
**/

, final member procedure construct
  ( self in out nocopy data_row_t
  , p_table_owner in varchar2
  , p_table_name in varchar2
  , p_dml_operation in varchar2
  , p_key in anydata
  )
/*
This procedure is there since Oracle Object Types do not allow to invoke a super constructor.
Therefore this procedure can be called instead in a sub type constructor like this:

(self as data_row_t).construct(p_table_owner, p_table_name, p_dml_operation, p_key);

This procedure also sets dml_timestamp to the sytem timestamp using the systimestamp() function.
*/
  
, static
  function deserialize
  ( p_obj_type in varchar2 -- the (schema and) name of the object type to convert to, e.g. DATA_ROW_T
  , p_obj in clob -- the JSON representation
  )
  return data_row_t
/* Deserialize a JSON object to an Oracle Object Type. */
  
, final
  member function get_type
  ( self in data_row_t
  )
  return varchar2
/* Get the schema and name of the type, e.g. SYS.NUMBER or DATA_ROW_T. */
  
, final
  member function serialize
  ( self in data_row_t
  )
  return clob
/* Serialize an Oracle Object Type to a JSON object. */
  
, member procedure serialize
  ( self in data_row_t
  , p_json_object in out nocopy json_object_t
  )
/* Serialize this type, every sub type must add its attributes (in capital letters). */
  
, member function repr
  ( self in data_row_t
  )
  return clob
/* Get the pretty printed JSON representation of a data row (or one of its sub types). */
  
, final
  member procedure print
  ( self in data_row_t
  )
/*
Print the object type and representation using dbug.print() or dbms_output.put_line().
At most 2000 characters are printed for the representation.
*/
)
not instantiable
not final;
/

