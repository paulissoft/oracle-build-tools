prompt --application/shared_components/user_interface/themes
begin
--   Manifest
--     THEME: 138
--   Manifest End
wwv_flow_api.component_begin (
 p_version_yyyy_mm_dd=>'2020.10.01'
,p_release=>'20.2.0.00.20'
,p_default_workspace_id=>2601326064169245
,p_default_application_id=>138
,p_default_id_offset=>151530112565241691
,p_default_owner=>'ORACLE_TOOLS'
);
wwv_flow_api.create_theme(
 p_id=>wwv_flow_api.id(57150692692461228)
,p_theme_id=>42
,p_theme_name=>'Universal Theme'
,p_theme_internal_name=>'UNIVERSAL_THEME'
,p_ui_type_name=>'DESKTOP'
,p_navigation_type=>'L'
,p_nav_bar_type=>'LIST'
,p_reference_id=>4070917134413059350
,p_is_locked=>false
,p_default_page_template=>wwv_flow_api.id(57068491006461165)
,p_default_dialog_template=>wwv_flow_api.id(57053496983461158)
,p_error_template=>wwv_flow_api.id(57055009665461160)
,p_printer_friendly_template=>wwv_flow_api.id(57068491006461165)
,p_breadcrumb_display_point=>'REGION_POSITION_01'
,p_sidebar_display_point=>'REGION_POSITION_02'
,p_login_template=>wwv_flow_api.id(57055009665461160)
,p_default_button_template=>wwv_flow_api.id(57148551375461217)
,p_default_region_template=>wwv_flow_api.id(57096232842461183)
,p_default_chart_template=>wwv_flow_api.id(57096232842461183)
,p_default_form_template=>wwv_flow_api.id(57096232842461183)
,p_default_reportr_template=>wwv_flow_api.id(57096232842461183)
,p_default_tabform_template=>wwv_flow_api.id(57096232842461183)
,p_default_wizard_template=>wwv_flow_api.id(57096232842461183)
,p_default_menur_template=>wwv_flow_api.id(57105630353461191)
,p_default_listr_template=>wwv_flow_api.id(57096232842461183)
,p_default_irr_template=>wwv_flow_api.id(57095101370461182)
,p_default_report_template=>wwv_flow_api.id(57118707194461198)
,p_default_label_template=>wwv_flow_api.id(57147718564461213)
,p_default_menu_template=>wwv_flow_api.id(57149353394461218)
,p_default_calendar_template=>wwv_flow_api.id(57149407465461220)
,p_default_list_template=>wwv_flow_api.id(57146091836461212)
,p_default_nav_list_template=>wwv_flow_api.id(57137898888461208)
,p_default_top_nav_list_temp=>wwv_flow_api.id(57137898888461208)
,p_default_side_nav_list_temp=>wwv_flow_api.id(57137491506461207)
,p_default_nav_list_position=>'SIDE'
,p_default_dialogbtnr_template=>wwv_flow_api.id(57086684584461176)
,p_default_dialogr_template=>wwv_flow_api.id(57074706508461172)
,p_default_option_label=>wwv_flow_api.id(57147718564461213)
,p_default_required_label=>wwv_flow_api.id(57147781558461215)
,p_default_page_transition=>'NONE'
,p_default_popup_transition=>'NONE'
,p_default_navbar_list_template=>wwv_flow_api.id(57138944021461209)
,p_file_prefix => nvl(wwv_flow_application_install.get_static_theme_file_prefix(42),'#IMAGE_PREFIX#themes/theme_42/1.2/')
,p_files_version=>62
,p_icon_library=>'FONTAPEX'
,p_javascript_file_urls=>wwv_flow_string.join(wwv_flow_t_varchar2(
'#IMAGE_PREFIX#libraries/apex/#MIN_DIRECTORY#widget.stickyWidget#MIN#.js?v=#APEX_VERSION#',
'#THEME_IMAGES#js/theme42#MIN#.js?v=#APEX_VERSION#'))
,p_css_file_urls=>'#THEME_IMAGES#css/Core#MIN#.css?v=#APEX_VERSION#'
);
wwv_flow_api.component_end;
end;
/
