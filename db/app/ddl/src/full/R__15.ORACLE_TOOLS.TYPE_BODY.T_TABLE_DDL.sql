CREATE OR REPLACE TYPE BODY "ORACLE_TOOLS"."T_TABLE_DDL" IS

overriding member procedure migrate
( self in out nocopy oracle_tools.t_table_ddl
, p_source in oracle_tools.t_schema_ddl
, p_target in oracle_tools.t_schema_ddl
)
is
  l_source_table_object oracle_tools.t_table_object := treat(p_source.obj as oracle_tools.t_table_object);
  l_target_table_object oracle_tools.t_table_object := treat(p_target.obj as oracle_tools.t_table_object);
  l_source_member_ddl_tab oracle_tools.t_schema_ddl_tab;
  l_target_member_ddl_tab oracle_tools.t_schema_ddl_tab;
  l_table_column_ddl oracle_tools.t_schema_ddl;
begin
$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.pkg_ddl_defs.c_debugging >= 2 $then
  dbug.enter($$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.' || 'MIGRATE');
  dbug.print(dbug."input", 'p_source.obj.id: %s; p_target.obj.id: %s', p_source.obj.id, p_target.obj.id);
$end

  -- first the standard things
  oracle_tools.t_schema_ddl.migrate
  ( p_source => p_source
  , p_target => p_target
  , p_schema_ddl => self
  );

$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.pkg_ddl_defs.c_debugging >= 2 $then
  dbug.print
  ( dbug."info"
  , 'l_source_table_object.tablespace_name(): %s; l_target_table_object.tablespace_name(): %s'
  , l_source_table_object.tablespace_name()
  , l_target_table_object.tablespace_name()
  );
$end

  -- check if tablespace names are equal
  if l_source_table_object.tablespace_name() != l_target_table_object.tablespace_name()
  then
    self.add_ddl
    ( p_verb => 'ALTER'
      -- the schema is
    , p_text => 'ALTER TABLE "' ||
                l_target_table_object.object_schema() ||
                '"."' ||
                l_target_table_object.object_name() ||
                '" MOVE TABLESPACE "' ||
                l_source_table_object.tablespace_name() ||
                '"'
    , p_add_sqlterminator => case when oracle_tools.pkg_ddl_defs.c_use_sqlterminator then 1 else 0 end
    );

    -- the table indexes will become unusable after the move tablespace so rebuild them (dynamically)
    self.add_ddl
    ( p_verb => 'ALTER'
      -- the schema is
    , p_text => q'[
BEGIN
  FOR R IN
  ( SELECT  'ALTER INDEX "' || A.OWNER || '"."' || A.INDEX_NAME || '" REBUILD' AS CMD
    FROM    ALL_INDEXES A
    WHERE   A.TABLE_OWNER = ']' || l_target_table_object.object_schema() || q'['
    AND     A.TABLE_NAME = ']' || l_target_table_object.object_name() || q'['
    AND     A.STATUS = 'UNUSABLE'
    ORDER BY
           CMD
  )
  LOOP
    EXECUTE IMMEDIATE R.CMD;
  END LOOP;
END;]'
    , p_add_sqlterminator => case when oracle_tools.pkg_ddl_defs.c_use_sqlterminator then 1 else 0 end
    );
  end if;

  oracle_tools.pkg_ddl_util.get_member_ddl
  ( p_source
  , l_source_member_ddl_tab
  );
  oracle_tools.pkg_ddl_util.get_member_ddl
  ( p_target
  , l_target_member_ddl_tab
  );

  for r in
  ( select  value(s) as source_schema_ddl
    ,       value(t) as target_schema_ddl
    from    table(l_source_member_ddl_tab) s
            full outer join table(l_target_member_ddl_tab) t
            on t.obj = s.obj -- map function is used
    order by
            treat(s.obj as oracle_tools.t_table_column_object).member#() nulls last -- dropping columns after adding (since we might drop the last column if we reverse it)
  )
  loop
    l_table_column_ddl := null;
    if r.source_schema_ddl is null
    then
$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.pkg_ddl_defs.c_debugging >= 2 $then
      dbug.print(dbug."info", '*** target column ***');
      r.target_schema_ddl.print();
$end
      oracle_tools.t_schema_ddl.create_schema_ddl
      ( r.target_schema_ddl.obj
      , oracle_tools.t_ddl_tab()
      , l_table_column_ddl
      );
      l_table_column_ddl.uninstall(r.target_schema_ddl);
    elsif r.target_schema_ddl is null
    then
$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.pkg_ddl_defs.c_debugging >= 2 $then
      dbug.print(dbug."info", '*** source column ***');
      r.source_schema_ddl.print();
$end
      oracle_tools.t_schema_ddl.create_schema_ddl
      ( r.source_schema_ddl.obj
      , oracle_tools.t_ddl_tab()
      , l_table_column_ddl
      );
      l_table_column_ddl.install(r.source_schema_ddl);
    elsif r.source_schema_ddl <> r.target_schema_ddl
    then
$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.pkg_ddl_defs.c_debugging >= 2 $then
      dbug.print(dbug."info", '*** source column ***');
      r.source_schema_ddl.print();
      dbug.print(dbug."info", '*** target column ***');
      r.target_schema_ddl.print();
$end
      oracle_tools.t_schema_ddl.create_schema_ddl
      ( r.source_schema_ddl.obj
      , oracle_tools.t_ddl_tab()
      , l_table_column_ddl
      );
      l_table_column_ddl.migrate
      ( p_source => r.source_schema_ddl
      , p_target => r.target_schema_ddl
      );
    end if;
    if l_table_column_ddl is not null and l_table_column_ddl.ddl_tab is not null and l_table_column_ddl.ddl_tab.count > 0
    then
      for i_idx in l_table_column_ddl.ddl_tab.first .. l_table_column_ddl.ddl_tab.last
      loop
        self.add_ddl
        ( p_verb => l_table_column_ddl.ddl_tab(i_idx).verb()
          -- the schema is
        , p_text_tab => l_table_column_ddl.ddl_tab(i_idx).text_tab
        );
      end loop;
    end if;
$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.pkg_ddl_defs.c_debugging >= 2 $then
    if l_table_column_ddl is not null
    then
      dbug.print(dbug."info", '*** result column ***');
      l_table_column_ddl.print();
    end if;
$end
  end loop;

$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.pkg_ddl_defs.c_debugging >= 2 $then
  dbug.leave;
$end
end migrate;

overriding member procedure uninstall
( self in out nocopy oracle_tools.t_table_ddl
, p_target in oracle_tools.t_schema_ddl
)
is
begin
$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.pkg_ddl_defs.c_debugging >= 2 $then
  dbug.enter($$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.' || 'UNINSTALL');
$end

  self.add_ddl
  ( p_verb => 'DROP'
  , p_text => 'DROP ' || p_target.obj.dict_object_type() || ' ' || p_target.obj.fq_object_name() || ' PURGE'
  , p_add_sqlterminator => case when oracle_tools.pkg_ddl_defs.c_use_sqlterminator then 1 else 0 end
  );

$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.pkg_ddl_defs.c_debugging >= 2 $then
  dbug.leave;
$end
end uninstall;

overriding member procedure add_ddl
( self in out nocopy oracle_tools.t_table_ddl
, p_verb in varchar2
, p_text in clob
, p_add_sqlterminator in integer
)
is
  -- GPA 2017-03-14 #141588789 As a CD developer I need to be able to import tables/grants into an Oracle XE database
  l_find_expr constant varchar2(100) := '(SEGMENT CREATION (DEFERRED|IMMEDIATE))';
  l_repl_expr constant varchar2(100) := null;
begin
$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.pkg_ddl_defs.c_debugging >= 2 $then
  dbug.enter($$PLSQL_UNIT_OWNER || '.' || $$PLSQL_UNIT || '.' || 'ADD_DDL');
  dbug.print(dbug."input", 'self:');
  self.print();
  dbug.print(dbug."input", 'p_verb: %s; p_add_sqlterminator: %s', p_verb, p_add_sqlterminator);
$end

  (self as oracle_tools.t_schema_ddl).add_ddl
  ( p_verb => p_verb
  , p_text => regexp_replace(p_text, l_find_expr, l_repl_expr, 1, 1, 'im') -- case insensitive multi-line search/replace
  , p_add_sqlterminator => p_add_sqlterminator
  );

$if oracle_tools.cfg_pkg.c_debugging and oracle_tools.pkg_ddl_defs.c_debugging >= 2 $then
  dbug.leave;
$end
end add_ddl;

end;
/

