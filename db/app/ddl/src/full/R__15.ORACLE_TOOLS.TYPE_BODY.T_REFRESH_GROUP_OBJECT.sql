CREATE OR REPLACE TYPE BODY "ORACLE_TOOLS"."T_REFRESH_GROUP_OBJECT" AS

constructor function t_refresh_group_object
( self in out nocopy oracle_tools.t_refresh_group_object
, p_object_schema in varchar2
, p_object_name in varchar2
)
return self as result
is
begin
$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.pkg_ddl_defs.c_debugging >= 3 $then
  dbug.enter($$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.CONSTRUCTOR');
  dbug.print
  ( dbug."input"
  , 'p_object_schema: %s; p_object_name: %s'
  , p_object_schema
  , p_object_name
  );
$end

  self.network_link$ := null;
  self.object_schema$ := p_object_schema;
  self.object_name$ := p_object_name;

  oracle_tools.t_schema_object.normalize(self);

$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.pkg_ddl_defs.c_debugging >= 3 $then
  dbug.leave;
$end

  return;
end;

overriding member function object_type
return varchar2
deterministic
is
begin
  return 'REFRESH_GROUP';
end object_type;

overriding member function dict_last_ddl_time
return date
is
begin
  -- often mapped on MV
  return oracle_tools.t_schema_object.dict_last_ddl_time
         ( p_object_schema => self.object_schema()
         , p_dict_object_type => 'MATERIALIZED VIEW'
         , p_object_name => self.object_name()
         );
end dict_last_ddl_time;

end;
/

