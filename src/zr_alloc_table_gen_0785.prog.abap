*&---------------------------------------------------------------------*
*& Reporte: ZR_ALLOC_TABLE_GEN_0785
*& Generación masiva de Tablas de Asignación a partir de un Excel
*& Referencia: EF D136A - Tablas de Asignación
*&---------------------------------------------------------------------*
REPORT zr_alloc_table_gen_0785.

SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-001.

PARAMETERS: p_file TYPE string LOWER CASE OBLIGATORY.

SELECTION-SCREEN SKIP.

PARAMETERS: p_sim  RADIOBUTTON GROUP rb1 DEFAULT 'X', " Simulación
            p_real RADIOBUTTON GROUP rb1.             " Ejecución Real

SELECTION-SCREEN END OF BLOCK b01.


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

  NEW zcl_alloc_table_gen_0785(
    i_file_path  = p_file
    i_simulation = lv_simulation
  )->process( ).
