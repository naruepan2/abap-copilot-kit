*&---------------------------------------------------------------------*
*& Include          YSMILE_SALV_TEMPL_EDIT2_C02
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& ALV Events Class
*&---------------------------------------------------------------------*
CLASS lcl_salv_events DEFINITION.
  PUBLIC SECTION.

    INTERFACES if_salv_gui_om_edit_strct_lstr.
    INTERFACES if_salv_gui_toolbar_listener.
    INTERFACES if_salv_gui_om_ctxt_menu_lstr.

    METHODS constructor
      IMPORTING io_view TYPE REF TO lcl_salv OPTIONAL
                io_main TYPE REF TO lcl_main OPTIONAL.
* Event Handler for HOTSPOT event
    METHODS: on_link_click_handler
      FOR EVENT link_click OF cl_salv_events_table
      IMPORTING row column.
* Event Handler for DOUBLE-CLICK event
    METHODS on_double_click_handler
      FOR EVENT double_click OF cl_salv_events_table
      IMPORTING row column.
* Event Handler for Custom User Command event
    METHODS on_user_command_handler
      FOR EVENT added_function OF cl_salv_events_table
      IMPORTING e_salv_function.
* Event Handler for Control Before Execution of a Generic ALV Function
    METHODS on_before_function_handler
      FOR EVENT before_salv_function OF cl_salv_events_table
      IMPORTING e_salv_function.
* Event Handler for Control After Execution of a Generic ALV Function
    METHODS on_after_function_handler
      FOR EVENT after_salv_function OF cl_salv_events_table
      IMPORTING e_salv_function.

  PRIVATE SECTION.

    DATA mo_view TYPE REF TO lcl_salv.
    DATA mo_main TYPE REF TO lcl_main.
    DATA mo_grid TYPE REF TO cl_gui_alv_grid.

    METHODS _set_register_modified
      RETURNING VALUE(ro_lcl_events) TYPE REF TO lcl_salv_events.

ENDCLASS.

*&---------------------------------------------------------------------*
*& ALV Class for Display
*&---------------------------------------------------------------------*
CLASS lcl_salv DEFINITION FINAL.

  PUBLIC SECTION.
    METHODS display_alv.
    METHODS refresh_alv
      IMPORTING is_stable         TYPE lvc_s_stbl OPTIONAL
                iv_set_all_stable TYPE flag OPTIONAL
                iv_refresh_mode   TYPE salv_de_constant DEFAULT if_salv_c_refresh=>soft.
    METHODS get_salv_table
      RETURNING VALUE(ro_salv) TYPE REF TO cl_salv_table.
    METHODS get_events
      RETURNING VALUE(ro_events) TYPE REF TO lcl_salv_events.

  PRIVATE SECTION.

    DATA mo_salv TYPE REF TO cl_salv_table.
    DATA mo_extended_grid_api TYPE REF TO if_salv_gui_om_extend_grid_api.
    DATA mo_events TYPE REF TO lcl_salv_events.

    DATA mv_all_cells_input_enabled	TYPE abap_bool.
    DATA mv_set_celltab_columnnames	TYPE abap_bool.

    METHODS _create_salv_instance
      RETURNING VALUE(ro_salv) TYPE REF TO cl_salv_table.
    METHODS _display_salv_instance.
    METHODS _set_pf_status
      IMPORTING iv_report        TYPE syrepid DEFAULT sy-repid
                iv_pfstatus      TYPE sypfkey OPTIONAL
                iv_set_functions TYPE salv_de_constant DEFAULT cl_salv_model_base=>c_functions_all.
    METHODS _set_pf_title.
    METHODS _set_layout.
    METHODS _set_top_end_of_page.
    METHODS _set_display_setting.
    METHODS _set_selection_mode.
    METHODS _set_functional_settings.
    METHODS _set_columns.
    METHODS _set_technical_columns.
    METHODS _set_t_celltab_columnname
      IMPORTING iv_celltab_columnname TYPE lvc_fname.
    METHODS _set_technical_client.
    METHODS _modify_columns
      IMPORTING io_columns TYPE REF TO cl_salv_columns_table.
    METHODS _set_events.
    METHODS _get_events_instance
      RETURNING VALUE(ro_events) TYPE REF TO lcl_salv_events.
    METHODS _set_aggregations.
    METHODS _set_filters.
    METHODS _set_sorts.
    METHODS _set_screen_popup.
    METHODS _register_grid_editable.
    METHODS _get_extended_grid_api
      RETURNING VALUE(ro_extended_grid_api) TYPE REF TO if_salv_gui_om_extend_grid_api.
    METHODS _set_editable_columns.
    METHODS _set_editable_column
      IMPORTING iv_columnname              TYPE lvc_fname
                iv_drop_down_columnname    TYPE lvc_fname OPTIONAL
                is_register_f4_help        TYPE if_salv_gui_om_edit_restricted=>ys_f4_help_attributes OPTIONAL
                iv_urge_foreign_key_check  TYPE abap_bool DEFAULT abap_false
                iv_all_cells_input_enabled TYPE abap_bool DEFAULT abap_true
                iv_set_listener            TYPE abap_bool DEFAULT abap_true.
    METHODS _find_cellstyle_from_itab
      RETURNING VALUE(ro_instance) TYPE REF TO lcl_salv.
    METHODS _get_result_of_cellstyle
      EXPORTING ev_all_cells_input_enabled TYPE abap_bool
                ev_set_celltab_columnnames TYPE abap_bool.

ENDCLASS.

*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& ALV Events Class for Display Implementation
*&---------------------------------------------------------------------*
CLASS lcl_salv_events IMPLEMENTATION.
  METHOD constructor.
    mo_view = COND #( WHEN io_view IS BOUND THEN io_view ELSE mo_view ).
    mo_main = COND #( WHEN io_main IS BOUND THEN io_main ELSE mo_main ).
  ENDMETHOD.

  METHOD on_link_click_handler.
  ENDMETHOD.

  METHOD on_double_click_handler.
  ENDMETHOD.

  METHOD on_user_command_handler.
  ENDMETHOD.

  METHOD on_before_function_handler.
  ENDMETHOD.

  METHOD on_after_function_handler.
  ENDMETHOD.

  METHOD if_salv_gui_om_edit_strct_lstr~on_check_changed_data.
    "------------------------------------------------------------------------------------"
    " See Example from link:
    "   https://community.sap.com/t5/application-development-and-automation-blog-posts/handling-data-changed-event-in-the-editable-salv-grid/ba-p/13559428
    "------------------------------------------------------------------------------------"
**  Example:
**    o_ui_data_modify->get_ui_changes( IMPORTING t_modified_cells      = DATA(lt_modified_cells)
**                                                t_good_cells          = DATA(lt_good_cells)
**                                                t_deleted_rows        = DATA(lt_deleted_rows)
**                                                t_inserted_rows       = DATA(lt_inserted_rows)
**                                                rt_modified_data_rows = DATA(lt_modified_data_rows) ).
  ENDMETHOD.

  METHOD if_salv_gui_om_edit_strct_lstr~on_f4_request.
  ENDMETHOD.

  METHOD if_salv_gui_toolbar_listener~build_toolbar.
    _set_register_modified( ).      " To register when ALV data was/were changed

    "------------------------------------------------------------------------------------"
    " See Example from program: SALV_OM_DEMO_TABLE_TOOLBAR
    "------------------------------------------------------------------------------------"
    " Add custom logic to insert custom toolbar
  ENDMETHOD.

  METHOD if_salv_gui_toolbar_listener~build_menu.
    "------------------------------------------------------------------------------------"
    " See Example from program: SALV_OM_DEMO_TABLE_TOOLBAR
    "------------------------------------------------------------------------------------"
    " Add custom logic to build dynamic menu of toolbar
  ENDMETHOD.

  METHOD if_salv_gui_om_ctxt_menu_lstr~before_display_context_menu.
    " Add custom logic to insert custom context menu (Trigger when click right)
  ENDMETHOD.

  METHOD _set_register_modified.
    CALL FUNCTION 'GET_GLOBALS_FROM_SLVC_FULLSCR'
      IMPORTING
        e_grid = mo_grid.

    IF mo_grid IS NOT BOUND.
      RETURN.
    ENDIF.

    CALL METHOD mo_grid->register_edit_event
      EXPORTING
        i_event_id = cl_gui_alv_grid=>mc_evt_modified.
  ENDMETHOD.
ENDCLASS.

*&---------------------------------------------------------------------*
*& ALV Class for Display Implementation
*&---------------------------------------------------------------------*
CLASS lcl_salv IMPLEMENTATION.
  METHOD display_alv.
    DATA(lo_salv) = me->_create_salv_instance( ).

    IF lo_salv IS NOT BOUND.
      RETURN.
    ENDIF.

* Set Events
    me->_set_events( ).

* Set each columns of the ALV
    me->_set_columns( ).

* Set PF-Status
    me->_set_pf_status( iv_pfstatus = space ).

* Set PF-Title
*    me->_set_pf_title( ).

* Set Layout
    me->_set_layout( ).

*** Set Top and End of Page
**    me->_set_top_end_of_page( ).

* Set appearance of the ALV
    me->_set_display_setting( ).

* Set selection mode
    me->_set_selection_mode( ).

* Set Functionality
**    me->_set_functional_settings( ).

*** Apply Aggregations & Filters & Sorts
**    me->_set_aggregations( ).
**    me->_set_filters( ).
**    me->_set_sorts( ).
**    me->_set_screen_popup( ).

* Displaying the ALV
    me->_display_salv_instance( ).
  ENDMETHOD.

  METHOD refresh_alv.
    DATA: ls_stable TYPE lvc_s_stbl.

    IF mo_salv IS NOT BOUND.
      RETURN.
    ENDIF.

    ls_stable = is_stable.

    IF iv_set_all_stable IS NOT INITIAL.
      ls_stable = VALUE #( col = abap_true
                           row = abap_true ).
    ENDIF.

    mo_salv->refresh( EXPORTING s_stable     = ls_stable
                                refresh_mode = iv_refresh_mode ).
  ENDMETHOD.

  METHOD get_salv_table.
    ro_salv = mo_salv.
  ENDMETHOD.

  METHOD get_events.
    ro_events = mo_events.
  ENDMETHOD.

  METHOD _create_salv_instance.
    DATA(lr_data) = go_main->get_result_data( ).

    IF lr_data IS NOT BOUND.
      RETURN.
    ENDIF.

    ASSIGN lr_data->* TO FIELD-SYMBOL(<lt_data>).

    TRY.
        cl_salv_table=>factory(
          IMPORTING
            r_salv_table = mo_salv
          CHANGING
            t_table      = <lt_data> ).
      CATCH cx_salv_msg.
        RETURN.
    ENDTRY.

    ro_salv = mo_salv.
  ENDMETHOD.

  METHOD _display_salv_instance.
    mo_salv->display( ).
  ENDMETHOD.

  METHOD _set_columns.
    DATA: lo_columns TYPE REF TO cl_salv_columns_table.
*...Get all the Columns
    lo_columns = mo_salv->get_columns( ).
    lo_columns->set_optimize( ).

* Freeze Key Columns
    lo_columns->set_key_fixation( abap_false ).

* Register ALV Grid Editable
    me->_register_grid_editable( ).

* Find cellstyle_from_itab
    me->_find_cellstyle_from_itab( ).

* Set Column as Technical Column
    me->_set_technical_columns( ).

* Modify Column of ALV
    me->_modify_columns( lo_columns ).

* Set Editable Fields
    me->_set_editable_columns( ).
  ENDMETHOD.

  METHOD _modify_columns.
    DATA: lo_column TYPE REF TO cl_salv_column_table.
    DATA: lv_stext TYPE scrtext_s,
          lv_mtext TYPE scrtext_m,
          lv_ltext TYPE scrtext_l,
          lv_field TYPE lvc_fname.

    DEFINE mc_set_field.
* See Example Program: SALV_DEMO_TABLE_COLUMNS
      lv_field = &1.
      lv_stext = &2.
      lv_mtext = &2.
      lv_ltext = &2.

      TRY.
          lo_column ?= io_columns->get_column( lv_field ).
          lo_column->set_short_text( lv_stext ).
          lo_column->set_medium_text( lv_mtext ).
          lo_column->set_long_text( lv_ltext ).
          lo_column->set_sign( abap_true ).
        CATCH cx_salv_not_found.
          RETURN.
      ENDTRY.
    END-OF-DEFINITION.

** Change the properties of the Columns
*    mc_set_field:
*      'BUTXT'         'As Of Date'.

    "------------------------------------------------------------------------------------"
*** Set additional properties of the Columns
**    TRY.
**        lo_column ?= io_columns->get_column( '' ).
**        lo_column->set_icon( ).
**        lo_column->set_key( ).
**
**        lo_column ?= io_columns->get_column( '' ).
**        lo_column->set_cell_type( if_salv_c_cell_type=>checkbox ).
**        lo_column->set_key( ).
**      CATCH cx_salv_not_found.
**    ENDTRY.

  ENDMETHOD.

  METHOD _set_editable_columns.
    me->_get_result_of_cellstyle( IMPORTING ev_all_cells_input_enabled = DATA(lv_all_cells_input_enabled) ).

**   Example
*    me->_set_editable_column( EXPORTING iv_columnname              = 'BUTXT'
*                                        iv_urge_foreign_key_check  = abap_false
*                                        iv_all_cells_input_enabled = lv_all_cells_input_enabled ).
*    me->_set_editable_column( EXPORTING iv_columnname              = 'PERIV'
*                                        iv_urge_foreign_key_check  = abap_false
*                                        iv_all_cells_input_enabled = lv_all_cells_input_enabled ).
  ENDMETHOD.

  METHOD _set_technical_columns.
    DATA lo_column TYPE REF TO cl_salv_column_table.

    DATA(lo_columns) = mo_salv->get_columns( ).

    _set_technical_client( ).
    me->_get_result_of_cellstyle( IMPORTING ev_set_celltab_columnnames = DATA(lv_set_celltab_columnnames) ).

** Register ALV Color
    TRY.
**        lo_columns->set_color_column( 'T_COLOR' ).
      CATCH cx_salv_data_error.
    ENDTRY.

** Register ALV Cell type: hotspot, hyperlink, text, checkbox, checkbox(hotspot) ....
    TRY.
**        lo_columns->set_cell_type_column( 'T_CELLTYPE' ).     "if_salv_c_cell_type
      CATCH cx_salv_data_error.
    ENDTRY.

** Register ALV Exception (Traffic Light)
    TRY.
        lo_columns->set_exception_column( value = 'EXCEPTION' ).      "Set exception column
      CATCH cx_salv_data_error cx_salv_not_found.
    ENDTRY.

** Register Editable with T_CELLSTYLE
    IF lv_set_celltab_columnnames IS NOT INITIAL.
      _set_t_celltab_columnname( iv_celltab_columnname = 'T_CELLSTYLE' ).
    ENDIF.
  ENDMETHOD.

  METHOD _set_t_celltab_columnname.
    DATA lv_dummy_column TYPE lvc_fname VALUE 'DUMMY_EDITABLE'.

    TRY.
        CAST cl_salv_column_table( mo_salv->get_columns( )->get_column( lv_dummy_column ) )->set_technical( ).
      CATCH cx_salv_not_found.
        RETURN.
    ENDTRY.

    TRY.
        DATA(lo_editable) = _get_extended_grid_api( )->editable_restricted( ).
        lo_editable->set_t_celltab_columnname( iv_celltab_columnname ).
      CATCH cx_salv_api_contract_violation cx_salv_gui_om_not_editable.
    ENDTRY.

    me->_set_editable_column(
      iv_columnname              = lv_dummy_column
      iv_all_cells_input_enabled = abap_false ).
  ENDMETHOD.

  METHOD _set_technical_client.
    TRY.
        CAST cl_salv_column_table( mo_salv->get_columns( )->get_column( 'MANDT' ) )->set_technical( ).
      CATCH cx_salv_not_found.
    ENDTRY.
  ENDMETHOD.

  METHOD _set_pf_status.
    IF iv_pfstatus IS NOT INITIAL.
      " Calling method to set the PF-Status
      mo_salv->set_screen_status(
        pfstatus      = iv_pfstatus
        report        = iv_report
        set_functions = iv_set_functions ).
    ELSE.
      mo_salv->get_functions( )->set_all( ).

*     Note: Calling get_functions() resets toolbar registry
*           which effectively removes the standard Refresh button
*           This is intentional — Refresh conflicts with extended_grid_api editable state
      TRY.
          mo_salv->get_functions(
                )->get_function( EXPORTING function               = '&REFRESH'
                                           include_salv_functions = abap_true
                )->set_enable( value = abap_false ).
        CATCH cx_salv_wrong_call
        cx_salv_object_not_found.
      ENDTRY.
    ENDIF.
  ENDMETHOD.

  METHOD _set_pf_title.
*    SET TITLEBAR 'XXXX' WITH 'XXXX'.
  ENDMETHOD.

  METHOD _set_layout.
    DATA: lf_variant TYPE slis_vari,
          ls_key     TYPE salv_s_layout_key.

*   get layout object
    DATA(lo_layout) = mo_salv->get_layout( ).

*   set Layout save restriction
*   1. Set Layout Key .. Unique key identifies the Differenet ALVs
    ls_key-report = sy-repid.

    lo_layout->set_key( ls_key ).
*   2. Remove Save layout the restriction.
    lo_layout->set_save_restriction( if_salv_c_layout=>restrict_none ).
    lo_layout->set_default( abap_true ).

*   set initial Layout
    lf_variant = ''.
    lo_layout->set_initial_layout( lf_variant ).
  ENDMETHOD.

  METHOD _set_top_end_of_page.
    DATA: lo_h_label TYPE REF TO cl_salv_form_label,
          lo_f_label TYPE REF TO cl_salv_form_label,
          lo_h_flow  TYPE REF TO cl_salv_form_layout_flow,
          lo_f_flow  TYPE REF TO cl_salv_form_layout_flow.

    DATA(lo_header) = NEW cl_salv_form_layout_grid( ).
    DATA(lo_footer) = NEW cl_salv_form_layout_grid( ).

    "---------------------------------------------------------------------------------------------------"
    " See Example:
    "     https://zevolving.com/2008/09/salv-table-5-add-header-top-of-page-footer-end-of-page
    "---------------------------------------------------------------------------------------------------"
  ENDMETHOD.

  METHOD _set_display_setting.
    DATA(lo_disp_setting) = mo_salv->get_display_settings( ).

*   Set ZEBRA pattern
    lo_disp_setting->set_striped_pattern( abap_true ).

**   Title to ALV
*    lo_disp_setting->set_list_header( 'ALV Test for Display Settings' ).
  ENDMETHOD.

  METHOD _set_selection_mode.
    DATA(lo_selections) = mo_salv->get_selections( ).

    lo_selections->set_selection_mode( if_salv_c_selection_mode=>multiple ).
  ENDMETHOD.

  METHOD _set_functional_settings.
    DATA: lo_functional_settings TYPE REF TO cl_salv_functional_settings.

    "---------------------------------------------------------------------------------------------------"
    " See Example:
    "     Program: SALV_DEMO_TABLE_COLUMNS
    "---------------------------------------------------------------------------------------------------"
  ENDMETHOD.

  METHOD _set_events.
    DATA: lo_salv_events TYPE REF TO cl_salv_events_table.

*  Get all events
    DATA(lo_myevents) = _get_events_instance( ).
    lo_salv_events    = mo_salv->get_event( ).

*    SET HANDLER lo_myevents->on_user_command_handler FOR lo_salv_events.
*    SET HANDLER lo_myevents->on_link_click_handler FOR lo_salv_events.
*    SET HANDLER lo_myevents->on_double_click_handler FOR lo_salv_events.
*    SET HANDLER lo_myevents->on_before_function_handler FOR lo_salv_events.
*    SET HANDLER lo_myevents->on_after_function_handler FOR lo_salv_events.
  ENDMETHOD.

  METHOD _get_events_instance.
    IF mo_events IS NOT BOUND.
      mo_events = NEW lcl_salv_events( io_view = me
                                       io_main = go_main ).
    ENDIF.

    RETURN mo_events.
  ENDMETHOD.

  METHOD _set_aggregations.
    DATA: lo_aggrs TYPE REF TO cl_salv_aggregations.

    lo_aggrs = mo_salv->get_aggregations( ).
  ENDMETHOD.

  METHOD _set_filters.
    DATA: lo_filters TYPE REF TO cl_salv_filters.

    lo_filters = mo_salv->get_filters( ).
  ENDMETHOD.

  METHOD _set_sorts.
    DATA: lo_sort TYPE REF TO cl_salv_sorts.

    lo_sort = mo_salv->get_sorts( ).
  ENDMETHOD.

  METHOD _set_screen_popup.
**    mo_salv->_set_screen_popup(
**      start_column =
***      end_column   =
**      start_line   =
***      end_line     =
**    ).
  ENDMETHOD.

  METHOD _register_grid_editable.
    IF mo_salv IS NOT BOUND.
      RETURN.
    ENDIF.

* Get Restricted Use of extended Grid API
    DATA(lo_extended_grid_api) = me->_get_extended_grid_api( ).

    IF lo_extended_grid_api IS NOT BOUND.
      RETURN.
    ENDIF.

    " Set the toolbar listener and Context menu
    "   Note!! Set_toolbar_listener must come before get_functions()
    "          once extended_grid_api is activated, SAP requires the toolbar listener to be registered
    "          before any toolbar-related calls like get_functions()->set_all()
    TRY.
        " To hook event of if_salv_gui_toolbar_listener~build_toolbar
**        lo_extended_grid_api->set_toolbar_listener( _get_events_instance( ) ).
**        lo_extended_grid_api->set_context_menu_listener( _get_events_instance( ) ).
      CATCH cx_salv_gui_tb_api_violation    ##NO_HANDLER
            cx_salv_api_contract_violation  ##NO_HANDLER.
    ENDTRY.

    TRY.
        DATA(lo_editable) = lo_extended_grid_api->editable_restricted( ).

        IF lo_editable IS NOT BOUND.
          RETURN.
        ENDIF.

        lo_editable->request_data_set_of_size( size = if_salv_gui_om_edit_restricted=>large ).
      CATCH cx_salv_api_contract_violation cx_salv_gui_om_not_editable.
      CATCH cx_salv_not_found.
    ENDTRY.
  ENDMETHOD.

  METHOD _get_extended_grid_api.
    IF mo_salv IS NOT BOUND.
      RETURN.
    ENDIF.

    RETURN mo_salv->extended_grid_api( ).
  ENDMETHOD.

  METHOD _set_editable_column.
    IF iv_columnname IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lo_extended_grid_api) = _get_extended_grid_api( ).

    IF lo_extended_grid_api IS NOT BOUND.
      RETURN.
    ENDIF.

    TRY.
        DATA(lo_editable) = lo_extended_grid_api->editable_restricted( ).

        lo_editable->set_attributes_for_columnname( columnname                  = iv_columnname
                                                    drop_down_handle_columnname = iv_drop_down_columnname
                                                    s_register_f4_help          = is_register_f4_help
                                                    urge_foreign_key_check      = iv_urge_foreign_key_check
                                                    all_cells_input_enabled     = iv_all_cells_input_enabled ).

        " Set Change data listener
        IF iv_set_listener IS NOT INITIAL.
          lo_editable->set_listener( _get_events_instance( ) ).
        ENDIF.
      CATCH cx_salv_api_contract_violation cx_salv_gui_om_not_editable.
      CATCH cx_salv_not_found.
    ENDTRY.
  ENDMETHOD.

  METHOD _find_cellstyle_from_itab.
    ro_instance = me.

    mv_all_cells_input_enabled = abap_true.
    mv_set_celltab_columnnames = space.

    DATA(lr_data) = go_main->get_result_data( ).

    IF lr_data IS NOT BOUND.
      RETURN.
    ENDIF.

    ASSIGN lr_data->* TO FIELD-SYMBOL(<lt_data>).

    LOOP AT <lt_data> ASSIGNING FIELD-SYMBOL(<ls_data>).
      ASSIGN COMPONENT 'T_CELLSTYLE' OF STRUCTURE <ls_data> TO FIELD-SYMBOL(<lt_cellstyle>) ELSE UNASSIGN.
      IF sy-subrc <> 0.
        EXIT.
      ENDIF.

      IF <lt_cellstyle> IS ASSIGNED.
        IF <lt_cellstyle> IS NOT INITIAL.
          mv_set_celltab_columnnames = abap_true.
          EXIT.
        ENDIF.
      ENDIF.
    ENDLOOP.

    mv_all_cells_input_enabled = COND #( WHEN mv_set_celltab_columnnames IS NOT INITIAL THEN space ELSE abap_true ).
  ENDMETHOD.

  METHOD _get_result_of_cellstyle.
    ev_all_cells_input_enabled = mv_all_cells_input_enabled.
    ev_set_celltab_columnnames = mv_set_celltab_columnnames.
  ENDMETHOD.
ENDCLASS.
