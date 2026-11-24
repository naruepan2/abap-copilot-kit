*&---------------------------------------------------------------------*
*& Include          YSMILE_SALV_TEMPL_EDIT2_C01
*&---------------------------------------------------------------------*
*----------------------------------------------------------------------*
* CLASS lcx_error DEFINITION
*----------------------------------------------------------------------*
CLASS lcx_excpt DEFINITION FINAL INHERITING FROM cx_static_check.
ENDCLASS. " lcx_error DEFINITION

*&---------------------------------------------------------------------*
*& Main Class
*&---------------------------------------------------------------------*
CLASS lcl_main DEFINITION FINAL.

  PUBLIC SECTION.

    TYPES: BEGIN OF ty_alv_tech,
             exception   TYPE char1,
             t_color     TYPE lvc_t_scol,
             t_celltype  TYPE salv_t_int4_column,               " See attribute -> if_salv_c_cell_type
             t_cellstyle TYPE lvc_t_styl,
             dummy_editable TYPE abap_bool,                     " Internal used only to activate T_CELLSTYLE (do not deleted)
           END OF ty_alv_tech.

    TYPES: BEGIN OF ty_outtab.
             INCLUDE TYPE t001.
             INCLUDE TYPE ty_alv_tech.
    TYPES: END OF ty_outtab.

    TYPES tt_outtab TYPE TABLE OF ty_outtab.

    DATA gt_outtab TYPE tt_outtab.

    METHODS handle_pbo.

    METHODS handle_pai.

    METHODS start.

    METHODS select_data
      RAISING lcx_excpt.

    METHODS process_data.

    METHODS get_result_data
      RETURNING VALUE(rr_data) TYPE REF TO data.

    METHODS set_alv_cells_style
      IMPORTING iv_fname     TYPE lvc_fname
                iv_editable  TYPE flag DEFAULT abap_true
      CHANGING  ct_cellstyle TYPE lvc_t_styl.
    METHODS set_alv_cells_type
      IMPORTING iv_fname    TYPE lvc_fname
                iv_value    TYPE int4
      CHANGING  ct_celltype TYPE salv_t_int4_column.
    METHODS set_alv_cells_color
      IMPORTING iv_fname    TYPE lvc_fname
                is_color    TYPE lvc_s_colo OPTIONAL
                iv_nokeycol TYPE lvc_nokeyc OPTIONAL
      CHANGING  ct_color    TYPE lvc_t_scol.
    METHODS flag_select_deselect_all
      IMPORTING iv_deselect_all TYPE flag OPTIONAL
                iv_row          TYPE salv_de_row OPTIONAL
      CHANGING  ct_outtab       TYPE tt_outtab.

  PRIVATE SECTION.

    DATA mv_error_msg TYPE string.

ENDCLASS.

CLASS lcl_main IMPLEMENTATION.
  METHOD handle_pbo.
  ENDMETHOD.

  METHOD handle_pai.
  ENDMETHOD.

  METHOD start.
    TRY.
* Get selection data
        me->select_data( ).

* Process data
        me->process_data( ).
      CATCH lcx_excpt INTO DATA(go_excpt).
* Throw Exception
        MESSAGE me->mv_error_msg TYPE 'S'
          DISPLAY LIKE 'E'.
        LEAVE LIST-PROCESSING.
    ENDTRY.
  ENDMETHOD.

  METHOD select_data.

    SELECT * FROM t001 INTO CORRESPONDING FIELDS OF TABLE @gt_outtab UP TO 40 ROWS.

    IF me->gt_outtab IS INITIAL.
      me->mv_error_msg = 'No data found'.
      RAISE EXCEPTION TYPE lcx_excpt.
    ENDIF.
  ENDMETHOD.

  METHOD process_data.

    LOOP AT gt_outtab ASSIGNING FIELD-SYMBOL(<ls_outtab>).
      IF sy-tabix BETWEEN 1 AND 5.
        <ls_outtab>-exception = 1.
      ELSEIF sy-tabix BETWEEN 6 AND 10.
        <ls_outtab>-exception = 2.
      ELSE.
        <ls_outtab>-exception = 3.
      ENDIF.

      IF sy-tabix BETWEEN 1 AND 10.
        set_alv_cells_style(
          EXPORTING
            iv_fname     = 'BUTXT'
            iv_editable  = abap_true
          CHANGING
            ct_cellstyle = <ls_outtab>-t_cellstyle ).

        set_alv_cells_style(
          EXPORTING
            iv_fname     = 'LAND1'
            iv_editable  = abap_true
          CHANGING
            ct_cellstyle = <ls_outtab>-t_cellstyle ).
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD get_result_data.
    RETURN REF #( gt_outtab ).
  ENDMETHOD.

  METHOD set_alv_cells_style.
    DATA lw_styl TYPE lvc_s_styl.

    "------------------------------------------------------------------------------------"
    " Example: cl_gui_alv_grid=>mc_style_enabled / cl_gui_alv_grid=>mc_style_disabled
    "------------------------------------------------------------------------------------"
    READ TABLE ct_cellstyle ASSIGNING FIELD-SYMBOL(<lfw_cellstyle>) WITH KEY fieldname = iv_fname.
    IF sy-subrc = 0.
      <lfw_cellstyle>-style = COND #( WHEN iv_editable IS NOT INITIAL THEN cl_gui_alv_grid=>mc_style_enabled
                                      ELSE cl_gui_alv_grid=>mc_style_disabled ).
    ELSE.
      lw_styl-fieldname = iv_fname.
      lw_styl-style     = COND #( WHEN iv_editable IS NOT INITIAL THEN cl_gui_alv_grid=>mc_style_enabled
                                  ELSE cl_gui_alv_grid=>mc_style_disabled ).
      INSERT lw_styl INTO TABLE ct_cellstyle.
    ENDIF.
  ENDMETHOD.

  METHOD set_alv_cells_type.
    DATA lw_celltype TYPE salv_s_int4_column.

    "------------------------------------------------------------------------------------"
    " See: interface -> if_salv_c_cell_type
    "------------------------------------------------------------------------------------"
*    READ TABLE ct_celltype ASSIGNING FIELD-SYMBOL(<lfw_celltype>) WITH KEY columnname = iv_fname.
*    IF sy-subrc = 0.
*      <lfw_celltype>-value = iv_value.
*    ELSE.
*      lw_celltype-columnname = iv_fname.
*      lw_celltype-value      = iv_value.
*      INSERT lw_celltype INTO TABLE ct_celltype.
*    ENDIF.
  ENDMETHOD.

  METHOD set_alv_cells_color.
    DATA lw_color TYPE lvc_s_scol.

    "------------------------------------------------------------------------------------"
    " Use lvc_s_colo for set color
    "------------------------------------------------------------------------------------"
*    READ TABLE ct_color ASSIGNING FIELD-SYMBOL(<lfw_color>) WITH KEY fname = iv_fname.
*    IF sy-subrc = 0.
*      <lfw_color>-color    = COND #( WHEN is_color IS SUPPLIED THEN is_color ELSE <lfw_color>-color ).
*      <lfw_color>-nokeycol = COND #( WHEN iv_nokeycol IS SUPPLIED THEN iv_nokeycol ELSE <lfw_color>-nokeycol ).
*    ELSE.
*      lw_color-fname    = iv_fname.
*      lw_color-color    = is_color.
*      lw_color-nokeycol = iv_nokeycol.
*      INSERT lw_color INTO TABLE ct_color.
*    ENDIF.
  ENDMETHOD.

  METHOD flag_select_deselect_all.
    FIELD-SYMBOLS <lfw_outtab> TYPE ty_outtab.

*    IF iv_deselect_all IS SUPPLIED.
*      LOOP AT ct_outtab ASSIGNING <lfw_outtab>.
*        CASE iv_deselect_all.
*          WHEN abap_true.
*            <lfw_outtab>-chkbox = abap_false.
*          WHEN space.
*            <lfw_outtab>-chkbox = abap_true.
*        ENDCASE.
*      ENDLOOP.
*    ELSEIF iv_row IS SUPPLIED.
*      READ TABLE ct_outtab ASSIGNING <lfw_outtab> INDEX iv_row.
*      IF sy-subrc = 0.
*        <lfw_outtab>-chkbox = COND #( WHEN <lfw_outtab>-chkbox IS INITIAL THEN abap_true ELSE abap_false ).
*      ENDIF.
*    ENDIF.
  ENDMETHOD.
ENDCLASS.
