whenever sqlerror exit failure
whenever oserror exit failure

delete from "schema_version_tools_ddl";
commit;

prompt @V00000000000000__drop_all_objects.sql
@V00000000000000__drop_all_objects.sql
prompt @V20201115143000__t_text_tab.sql
@V20201115143000__t_text_tab.sql
prompt @V20201128105200__t_object_info_rec.sql
@V20201128105200__t_object_info_rec.sql
prompt @V20201215162500.03__t_object_info_tab.sql
@V20201215162500.03__t_object_info_tab.sql
prompt @V20210104170000.01__t_schema_object.sql
@V20210104170000.01__t_schema_object.sql
prompt @V20210104170000.02__t_schema_object_tab.sql
@V20210104170000.02__t_schema_object_tab.sql
prompt @V20210104170000.03__t_named_object.sql
@V20210104170000.03__t_named_object.sql
prompt @V20210104170000.04__t_dependent_or_granted_object.sql
@V20210104170000.04__t_dependent_or_granted_object.sql
prompt @V20210104170000.05__t_sequence_object.sql
@V20210104170000.05__t_sequence_object.sql
prompt @V20210104170000.06__t_type_spec_object.sql
@V20210104170000.06__t_type_spec_object.sql
prompt @V20210104170000.07__t_cluster_object.sql
@V20210104170000.07__t_cluster_object.sql
prompt @V20210104170000.08__t_table_object.sql
@V20210104170000.08__t_table_object.sql
prompt @V20210104170000.09__t_function_object.sql
@V20210104170000.09__t_function_object.sql
prompt @V20210104170000.10__t_package_spec_object.sql
@V20210104170000.10__t_package_spec_object.sql
prompt @V20210104170000.11__t_view_object.sql
@V20210104170000.11__t_view_object.sql
prompt @V20210104170000.12__t_procedure_object.sql
@V20210104170000.12__t_procedure_object.sql
prompt @V20210104170000.13__t_materialized_view_object.sql
@V20210104170000.13__t_materialized_view_object.sql
prompt @V20210104170000.14__t_materialized_view_log_object.sql
@V20210104170000.14__t_materialized_view_log_object.sql
prompt @V20210104170000.15__t_package_body_object.sql
@V20210104170000.15__t_package_body_object.sql
prompt @V20210104170000.16__t_type_body_object.sql
@V20210104170000.16__t_type_body_object.sql
prompt @V20210104170000.17__t_index_object.sql
@V20210104170000.17__t_index_object.sql
prompt @V20210104170000.18__t_trigger_object.sql
@V20210104170000.18__t_trigger_object.sql
prompt @V20210104170000.19__t_object_grant_object.sql
@V20210104170000.19__t_object_grant_object.sql
prompt @V20210104170000.20__t_constraint_object.sql
@V20210104170000.20__t_constraint_object.sql
prompt @V20210104170000.21__t_ref_constraint_object.sql
@V20210104170000.21__t_ref_constraint_object.sql
prompt @V20210104170000.22__t_synonym_object.sql
@V20210104170000.22__t_synonym_object.sql
prompt @V20210104170000.23__t_comment_object.sql
@V20210104170000.23__t_comment_object.sql
prompt @V20210104170000.24__t_java_source_object.sql
@V20210104170000.24__t_java_source_object.sql
prompt @V20210104170000.25__t_refresh_group_object.sql
@V20210104170000.25__t_refresh_group_object.sql
prompt @V20210104170000.26__t_procobj_object.sql
@V20210104170000.26__t_procobj_object.sql
prompt @V20210104170000.27__t_ddl.sql
@V20210104170000.27__t_ddl.sql
prompt @V20210104170000.28__t_ddl_tab.sql
@V20210104170000.28__t_ddl_tab.sql
prompt @V20210104170000.29__t_schema_ddl.sql
@V20210104170000.29__t_schema_ddl.sql
prompt @V20210105085700__t_schema_ddl_tab.sql
@V20210105085700__t_schema_ddl_tab.sql
prompt @V20210109160400__t_procobj_ddl.sql
@V20210109160400__t_procobj_ddl.sql
prompt @V20210109160700__t_comment_ddl.sql
@V20210109160700__t_comment_ddl.sql
prompt @V20210109161000__t_constraint_ddl.sql
@V20210109161000__t_constraint_ddl.sql
prompt @V20210109162300__t_object_grant_ddl.sql
@V20210109162300__t_object_grant_ddl.sql
prompt @V20210109162400__t_refresh_group_ddl.sql
@V20210109162400__t_refresh_group_ddl.sql
prompt @V20210110092100__t_table_ddl.sql
@V20210110092100__t_table_ddl.sql
prompt @V20210110092300__t_index_ddl.sql
@V20210110092300__t_index_ddl.sql
prompt @V20210110101600__t_synonym_ddl.sql
@V20210110101600__t_synonym_ddl.sql
prompt @V20210113114100__t_type_spec_ddl.sql
@V20210113114100__t_type_spec_ddl.sql
prompt @V20210118121300__t_materialized_view_ddl.sql
@V20210118121300__t_materialized_view_ddl.sql
prompt @V20210124084600.01__t_member_object.sql
@V20210124084600.01__t_member_object.sql
prompt @V20210124084600.02__t_type_attribute_object.sql
@V20210124084600.02__t_type_attribute_object.sql
prompt @V20210124084600.03__t_table_column_object.sql
@V20210124084600.03__t_table_column_object.sql
prompt @V20210124084600.04__t_type_attribute_ddl.sql
@V20210124084600.04__t_type_attribute_ddl.sql
prompt @V20210124084600.05__t_table_column_ddl.sql
@V20210124084600.05__t_table_column_ddl.sql
prompt @V20210209100900__t_argument_object.sql
@V20210209100900__t_argument_object.sql
prompt @V20210209103100__t_argument_object_tab.sql
@V20210209103100__t_argument_object_tab.sql
prompt @V20210209103400__t_type_method_object.sql
@V20210209103400__t_type_method_object.sql
prompt @V20210209130400__t_type_method_ddl.sql
@V20210209130400__t_type_method_ddl.sql
prompt @V20210323144200__t_sequence_ddl.sql
@V20210323144200__t_sequence_ddl.sql
prompt @V20210323150100__t_ddl_sequence.sql
@V20210323150100__t_ddl_sequence.sql
prompt @V20210327121100__t_trigger_ddl.sql
@V20210327121100__t_trigger_ddl.sql
prompt @V20221124104600__t_schema_object_filter.sql
@V20221124104600__t_schema_object_filter.sql
prompt @V20241101115700__schema_object_filters.sql
@V20241101115700__schema_object_filters.sql
prompt @V20241101115701__schema_objects.sql
@V20241101115701__schema_objects.sql
prompt @V20241101121700__schema_object_filter_results.sql
@V20241101121700__schema_object_filter_results.sql
prompt @V20241101121701__generate_ddl_session_schema_objects.sql
@V20241101121701__generate_ddl_session_schema_objects.sql

