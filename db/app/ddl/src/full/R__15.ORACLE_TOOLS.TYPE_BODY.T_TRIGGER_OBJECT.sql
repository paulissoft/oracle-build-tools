CREATE OR REPLACE TYPE BODY "ORACLE_TOOLS"."T_TRIGGER_OBJECT" AS

constructor function t_trigger_object
( self in out nocopy t_trigger_object
, p_base_object in t_named_object
, p_object_schema in varchar2
, p_object_name in varchar2
)
return self as result
is
begin
$if cfg_pkg.c_debugging and pkg_ddl_util.c_debugging >= 3 $then
  dbug.enter('T_TRIGGER_OBJECT.T_TRIGGER_OBJECT');
  dbug.print
  ( dbug."input"
  , 'p_base_object.id(): %s; p_object_schema: %s; p_object_name: %s'
  , p_base_object.id()
  , p_object_schema
  , p_object_name
  );
$end

  self.base_object$ := p_base_object;
  self.network_link$ := null;
  self.object_schema$ := p_object_schema;
  self.object_name$ := p_object_name;

$if cfg_pkg.c_debugging and pkg_ddl_util.c_debugging >= 3 $then
  dbug.leave;
$end

  return;
end;  

-- begin of getter(s)

overriding member function object_type
return varchar2
deterministic
is
begin
  return 'TRIGGER';
end;

overriding member function object_name
return varchar2
deterministic
is
begin
  return self.object_name$;
end object_name;

-- end of getter(s)

overriding member procedure chk
( self in t_trigger_object
, p_schema in varchar2
)
is
begin
$if cfg_pkg.c_debugging and pkg_ddl_util.c_debugging >= 2 $then
  dbug.enter('T_TRIGGER_OBJECT.CHK');
$end

  pkg_schema_object.chk_schema_object(p_dependent_or_granted_object => self, p_schema => p_schema);

  if self.object_schema() = p_schema
  then
    null; -- ok
  else
    raise_application_error(pkg_ddl_error.c_invalid_parameters, 'Object schema (' || self.object_schema() || ') must be ' || p_schema);
  end if;
  if self.base_object_schema() is null
  then
    raise_application_error(pkg_ddl_error.c_invalid_parameters, 'Base object schema should not be empty.');
  end if;

$if cfg_pkg.c_debugging and pkg_ddl_util.c_debugging >= 2 $then
  dbug.leave;
$end
end chk;

end;
/

