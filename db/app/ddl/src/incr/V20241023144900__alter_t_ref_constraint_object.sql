begin
  for r in
  ( select  'drop type ' || object_name as cmd
    from    user_objects
    where   object_type = 'TYPE'
    and     object_name = 'T_REF_CONSTRAINT_OBJECT'
  )
  loop
    execute immediate r.cmd;
  end loop;

  execute immediate q'[
CREATE TYPE "ORACLE_TOOLS"."T_REF_CONSTRAINT_OBJECT" authid current_user under oracle_tools.t_constraint_object
( ref_object$ oracle_tools.t_text_tab -- representation of an oracle_tools.t_constraint_object (use oracle_tools.t_constraint_object.deserialize): referenced primary / unique key constraint whose base object is the referencing table / view
, constructor function t_ref_constraint_object
  ( self in out nocopy oracle_tools.t_ref_constraint_object
  , p_base_object in oracle_tools.t_named_object
  , p_object_schema in varchar2
  , p_object_name in varchar2
  , p_constraint_type in varchar2 default null
  , p_column_names in varchar2 default null
  , p_ref_object in oracle_tools.t_constraint_object default null
  )
  return self as result
-- begin of getter(s)
, member function ref_object return oracle_tools.t_named_object deterministic
, overriding member function object_type return varchar2 deterministic
, member function ref_object_schema return varchar2 deterministic
, member function ref_object_type return varchar2 deterministic
, member function ref_object_name return varchar2 deterministic
, member function ref_base_object_schema return varchar2 deterministic
, member function ref_base_object_type return varchar2 deterministic
, member function ref_base_object_name return varchar2 deterministic
-- end of getter(s)
, overriding final map member function signature return varchar2 deterministic
, overriding member procedure chk
  ( self in oracle_tools.t_ref_constraint_object
  , p_schema in varchar2
  )
, final member procedure ref_object_schema
  ( self in out nocopy oracle_tools.t_ref_constraint_object
  , p_ref_object_schema in varchar2
  )
, static function get_ref_constraint -- get referenced primary / unique key constraint whose base object is the referencing table / view with those columns
  ( p_ref_base_object_schema in varchar2
  , p_ref_base_object_name in varchar2
  , p_ref_column_names in varchar2
  )
  return oracle_tools.t_constraint_object
)
final]';

  execute immediate 'GRANT EXECUTE ON T_REF_CONSTRAINT_OBJECT TO PUBLIC';
end;
/
