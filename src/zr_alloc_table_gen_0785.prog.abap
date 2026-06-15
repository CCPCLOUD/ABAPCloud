*&---------------------------------------------------------------------*
*& Reporte: ZR_ALLOC_TABLE_GEN_0785
*& Generación masiva de Tablas de Asignación a partir de un Excel
*& Referencia: EF D136A - Tablas de Asignación
*&---------------------------------------------------------------------*
REPORT zr_alloc_table_gen_0785.

INCLUDE zr_alloc_table_gen_0785_top.   " Pantalla de selección
INCLUDE zr_alloc_table_gen_0785_cls.   " Clase local LCL_ALLOC_TABLE_GEN


AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.

  DATA lt_files TYPE filetable.
  DATA lv_rc    TYPE i.

  cl_gui_frontend_services=>file_open_dialog(
    EXPORTING
      window_title      = 'Seleccionar archivo Excel'
      default_extension = 'XLSX'
      file_filter       = 'Excel (*.xlsx)|*.xlsx'
      multiselection    = abap_false
    CHANGING
      file_table        = lt_files
      rc                = lv_rc
    EXCEPTIONS
      OTHERS            = 1 ).

  IF sy-subrc = 0 AND lines( lt_files ) > 0.
    p_file = lt_files[ 1 ]-filename.
  ENDIF.


START-OF-SELECTION.

  DATA(lv_simulation) = COND abap_bool( WHEN p_sim = abap_true THEN abap_true ELSE abap_false ).

  NEW lcl_alloc_table_gen(
    i_file_path  = p_file
    i_simulation = lv_simulation
  )->process( ).
