*&---------------------------------------------------------------------*
*& Include ZRMM_MASS_ARTICLE_EXTEN_SEL
*& Eventos de la pantalla de seleccion
*&---------------------------------------------------------------------*

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.

  DATA: lt_file_table TYPE filetable,
        lv_rc         TYPE i,
        lv_action     TYPE i.

  CALL METHOD cl_gui_frontend_services=>file_open_dialog
    EXPORTING
      window_title            = 'Seleccionar archivo Excel de ampliación'
      default_extension       = 'xlsx'
      file_filter             = 'Archivos Excel (*.xlsx)|*.xlsx|'
      multiselection          = abap_false
    CHANGING
      file_table               = lt_file_table
      rc                        = lv_rc
      user_action               = lv_action
    EXCEPTIONS
      file_open_dialog_failed  = 1
      cntl_error                = 2
      error_no_gui              = 3
      not_supported_by_gui      = 4
      OTHERS                    = 5.

  IF sy-subrc = 0 AND lv_action = cl_gui_frontend_services=>action_ok.
    READ TABLE lt_file_table INTO DATA(ls_file) INDEX 1.
    IF sy-subrc = 0.
      p_file = ls_file-filename.
    ENDIF.
  ENDIF.
