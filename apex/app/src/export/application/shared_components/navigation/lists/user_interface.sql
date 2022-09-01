prompt --application/shared_components/navigation/lists/user_interface
begin
--   Manifest
--     LIST: User Interface
--   Manifest End
wwv_flow_api.component_begin (
 p_version_yyyy_mm_dd=>'2020.10.01'
,p_release=>'20.2.0.00.20'
,p_default_workspace_id=>2601326064169245
,p_default_application_id=>138
,p_default_id_offset=>127029477646494312
,p_default_owner=>'ORACLE_TOOLS'
);
wwv_flow_api.create_list(
 p_id=>wwv_flow_api.id(44994750710156350)
,p_name=>'User Interface'
,p_list_status=>'PUBLIC'
,p_required_patch=>wwv_flow_api.id(44972476785156272)
);
wwv_flow_api.create_list_item(
 p_id=>wwv_flow_api.id(44995099063156351)
,p_list_item_display_sequence=>10
,p_list_item_link_text=>'Theme Style Selection'
,p_list_item_link_target=>'f?p=&APP_ID.:10010:&SESSION.::&DEBUG.:10010:::'
,p_list_item_icon=>'fa-paint-brush'
,p_list_text_01=>'Set the default application look and feel'
,p_required_patch=>wwv_flow_api.id(44972476785156272)
,p_list_item_current_type=>'TARGET_PAGE'
);
wwv_flow_api.component_end;
end;
/
