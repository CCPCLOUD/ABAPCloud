*&---------------------------------------------------------------------*
*& Include ZRMM_MASS_ARTICLE_EXTEN_F01
*& Carga del archivo Excel local y parseo de las 5 hojas del layout
*& final conciliado (ARTMAS09_Layout_Carga_Ampliacion_Articulos_Final)
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*&      Form  UPLOAD_AND_PARSE_EXCEL
*&---------------------------------------------------------------------*
FORM upload_and_parse_excel USING pu_file  TYPE string
                            CHANGING cv_xdata TYPE xstring.

  DATA: lv_length TYPE i,
        lt_binary TYPE solix_tab,
        lv_msg    TYPE string.

  CLEAR cv_xdata.

  CALL METHOD cl_gui_frontend_services=>gui_upload
    EXPORTING
      filename                = pu_file
      filetype                = 'BIN'
    IMPORTING
      filelength               = lv_length
    CHANGING
      data_tab                 = lt_binary
    EXCEPTIONS
      file_open_error          = 1
      file_read_error          = 2
      no_batch                 = 3
      gui_refuse_filetransfer  = 4
      invalid_type             = 5
      no_authority              = 6
      unknown_error             = 7
      bad_data_format           = 8
      header_not_allowed        = 9
      separator_not_allowed     = 10
      header_too_long           = 11
      unknown_dp_error          = 12
      access_denied             = 13
      dp_out_of_memory          = 14
      disk_full                 = 15
      dp_timeout                = 16
      not_supported_by_gui      = 17
      error_no_gui              = 18
      OTHERS                    = 19.

  IF sy-subrc <> 0.
    lv_msg = |No fue posible leer el archivo local { pu_file }. Verifique la ruta y los permisos.|.
    PERFORM add_log USING icon_red_light 'Error' gc_sheet_articulos 0
                          space gc_nivel_material space 'E' lv_msg gc_no_docnum.
    RETURN.
  ENDIF.

  CALL FUNCTION 'SCMS_BINARY_TO_XSTRING'
    EXPORTING
      input_length = lv_length
      first_line   = 0
      last_line    = 0
    IMPORTING
      buffer       = cv_xdata
    TABLES
      binary_tab   = lt_binary
    EXCEPTIONS
      failed       = 1
      OTHERS       = 2.

  IF sy-subrc <> 0 OR cv_xdata IS INITIAL.
    lv_msg = 'No fue posible convertir el archivo a formato binario procesable.'.
    PERFORM add_log USING icon_red_light 'Error' gc_sheet_articulos 0
                          space gc_nivel_material space 'E' lv_msg gc_no_docnum.
    RETURN.
  ENDIF.

  " La lectura del .xlsx se realiza mediante CL_FDT_XL_SPREADSHEET
  " (verificar disponibilidad y firma exacta de metodos en el sistema
  " destino: WE60/SE24 -> CL_FDT_XL_SPREADSHEET). No se depende de
  " GET_WORKSHEET_NAMES: cada hoja se intenta leer directamente y,
  " si no existe o el archivo esta danado, se captura la excepcion.
  DATA: lo_xlsx TYPE REF TO cl_fdt_xl_spreadsheet.

  TRY.
      lo_xlsx = NEW cl_fdt_xl_spreadsheet( document_name = pu_file
                                            xdocument     = cv_xdata ).
    CATCH cx_root INTO DATA(lx_excel).
      lv_msg = |Archivo Excel inválido o dañado: { lx_excel->get_text( ) }|.
      PERFORM add_log USING icon_red_light 'Error' gc_sheet_articulos 0
                            space gc_nivel_material space 'E' lv_msg gc_no_docnum.
      RETURN.
  ENDTRY.

  PERFORM parse_worksheet USING lo_xlsx gc_sheet_articulos  CHANGING git_articulos.
  PERFORM parse_worksheet USING lo_xlsx gc_sheet_centros    CHANGING git_centros.
  PERFORM parse_worksheet USING lo_xlsx gc_sheet_almacenes  CHANGING git_almacenes.
  PERFORM parse_worksheet USING lo_xlsx gc_sheet_valoracion CHANGING git_valoracion.
  PERFORM parse_worksheet USING lo_xlsx gc_sheet_ventas     CHANGING git_ventas.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  PARSE_WORKSHEET
*&  Lee la hoja y delega en la forma tipada correspondiente
*&---------------------------------------------------------------------*
FORM parse_worksheet USING iu_xlsx  TYPE REF TO cl_fdt_xl_spreadsheet
                           iu_sheet TYPE string
                     CHANGING ct_data TYPE any TABLE.

  DATA: lr_raw TYPE REF TO data,
        lv_msg TYPE string.
  FIELD-SYMBOLS: <lt_raw> TYPE STANDARD TABLE.

  TRY.
      lr_raw = iu_xlsx->if_fdt_doc_spreadsheet~get_itab_from_worksheet( worksheet_name = iu_sheet ).
    CATCH cx_root INTO DATA(lx_sheet).
      lv_msg = |La hoja { iu_sheet } no existe o no pudo leerse: { lx_sheet->get_text( ) }. Verifique el layout final conciliado.|.
      PERFORM add_log USING icon_red_light 'Error' iu_sheet 0
                            space gc_nivel_material space 'E' lv_msg gc_no_docnum.
      RETURN.
  ENDTRY.

  ASSIGN lr_raw->* TO <lt_raw>.
  IF <lt_raw> IS NOT ASSIGNED.
    RETURN.
  ENDIF.

  DATA: lv_headers_ok TYPE abap_bool.
  PERFORM check_headers USING iu_sheet <lt_raw> CHANGING lv_headers_ok.
  IF lv_headers_ok = abap_false.
    lv_msg = |Los encabezados de la hoja { iu_sheet } no coinciden exactamente con el layout final conciliado.|.
    PERFORM add_log USING icon_red_light 'Error' iu_sheet gc_header_row
                          space gc_nivel_material space 'E' lv_msg gc_no_docnum.
    RETURN.
  ENDIF.

  CASE iu_sheet.
    WHEN gc_sheet_articulos.
      PERFORM fill_articulos  USING <lt_raw> CHANGING ct_data.
    WHEN gc_sheet_centros.
      PERFORM fill_centros    USING <lt_raw> CHANGING ct_data.
    WHEN gc_sheet_almacenes.
      PERFORM fill_almacenes  USING <lt_raw> CHANGING ct_data.
    WHEN gc_sheet_valoracion.
      PERFORM fill_valoracion USING <lt_raw> CHANGING ct_data.
    WHEN gc_sheet_ventas.
      PERFORM fill_ventas     USING <lt_raw> CHANGING ct_data.
  ENDCASE.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  CHECK_HEADERS
*&  Valida que los encabezados (fila 7) coincidan exactamente con el
*&  layout final conciliado (FS 2.4.1 - Validación de estructura)
*&---------------------------------------------------------------------*
FORM check_headers USING iu_sheet TYPE string
                         it_raw   TYPE STANDARD TABLE
                CHANGING cv_ok    TYPE abap_bool.

  DATA: lt_expected TYPE TABLE OF string.

  CASE iu_sheet.
    WHEN gc_sheet_articulos.
      lt_expected = VALUE #( ( `Material` ) ).
    WHEN gc_sheet_centros.
      lt_expected = VALUE #(
        ( `Material` ) ( `Centro` ) ( `Grupo compras` ) ( `Tipo MRP` )
        ( `Plazo entrega planificado` ) ( `Tipo aprovisionamiento` ) ( `Grupo carga` )
        ( `Verificación disponibilidad` ) ( `Centro beneficio` ) ( `País origen` )
        ( `Perfil distribución` ) ( `Stock negativo X/vacío` ) ( `Fuente aprovisionamiento` )
        ( `Valor de redondeo` ) ).
    WHEN gc_sheet_almacenes.
      lt_expected = VALUE #( ( `Material` ) ( `Centro` ) ( `Almacén` ) ).
    WHEN gc_sheet_valoracion.
      lt_expected = VALUE #(
        ( `Material` ) ( `Área valoración` ) ( `Clase valoración` ) ( `Control de precio` )
        ( `Precio promedio móvil` ) ( `Precio estándar` ) ( `Unidad de precio` ) ).
    WHEN gc_sheet_ventas.
      lt_expected = VALUE #(
        ( `Material` ) ( `Organización ventas` ) ( `Canal distribución` ) ( `Categoría ítem` )
        ( `Grupo imputación` ) ( `Fecha inicio AAAAMMDD` ) ( `Fecha fin AAAAMMDD` )
        ( `Material referencia precio` ) ( `Unidad de entrega` ) ).
    WHEN OTHERS.
      cv_ok = abap_false.
      RETURN.
  ENDCASE.

  cv_ok = abap_true.

  FIELD-SYMBOLS: <ls_header_row> TYPE any.
  READ TABLE it_raw ASSIGNING <ls_header_row> INDEX gc_header_row.
  IF sy-subrc <> 0.
    cv_ok = abap_false.
    RETURN.
  ENDIF.

  DATA: lv_col    TYPE i,
        lv_actual  TYPE string.
  LOOP AT lt_expected INTO DATA(lv_expected).
    lv_col = lv_col + 1.
    CLEAR lv_actual.
    PERFORM get_cell_value USING <ls_header_row> lv_col CHANGING lv_actual.
    IF lv_actual <> lv_expected.
      cv_ok = abap_false.
      RETURN.
    ENDIF.
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*&  Helper generico: obtiene el valor de la celda (columna N, base 1)
*&  de la fila generica devuelta por CL_FDT_XL_SPREADSHEET
*&---------------------------------------------------------------------*
FORM get_cell_value USING iu_row   TYPE any
                          iu_col   TYPE i
                 CHANGING cv_value TYPE string.

  DATA: lo_struct TYPE REF TO cl_abap_structdescr,
        lt_comp   TYPE cl_abap_structdescr=>component_table.

  CLEAR cv_value.
  lo_struct ?= cl_abap_typedescr=>describe_by_data( iu_row ).
  lt_comp = lo_struct->get_components( ).

  IF iu_col > lines( lt_comp ) OR iu_col < 1.
    RETURN.
  ENDIF.

  FIELD-SYMBOLS: <lv_cell> TYPE any.
  ASSIGN COMPONENT iu_col OF STRUCTURE iu_row TO <lv_cell>.
  IF <lv_cell> IS ASSIGNED.
    cv_value = <lv_cell>.
    CONDENSE cv_value.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  FILL_ARTICULOS  (hoja 01_ARTICULOS: 1 columna)
*&---------------------------------------------------------------------*
FORM fill_articulos USING it_raw TYPE STANDARD TABLE
                    CHANGING ct_data TYPE any TABLE.

  FIELD-SYMBOLS: <ls_raw> TYPE any.
  DATA: lv_idx TYPE i,
        ls_out TYPE gty_s_articulo,
        lt_out TYPE gtt_articulo.

  LOOP AT it_raw ASSIGNING <ls_raw>.
    lv_idx = sy-tabix.
    IF lv_idx < gc_first_data_row.
      CONTINUE.
    ENDIF.

    CLEAR ls_out.
    ls_out-row = lv_idx.
    PERFORM get_cell_value USING <ls_raw> 1 CHANGING ls_out-material.

    IF ls_out-material IS INITIAL.
      CONTINUE.
    ENDIF.

    APPEND ls_out TO lt_out.
  ENDLOOP.

  ct_data = lt_out.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  FILL_CENTROS  (hoja 02_CENTROS: 14 columnas)
*&---------------------------------------------------------------------*
FORM fill_centros USING it_raw TYPE STANDARD TABLE
                  CHANGING ct_data TYPE any TABLE.

  FIELD-SYMBOLS: <ls_raw> TYPE any.
  DATA: lv_idx TYPE i,
        ls_out TYPE gty_s_centro,
        lt_out TYPE gtt_centro.

  LOOP AT it_raw ASSIGNING <ls_raw>.
    lv_idx = sy-tabix.
    IF lv_idx < gc_first_data_row.
      CONTINUE.
    ENDIF.

    CLEAR ls_out.
    ls_out-row = lv_idx.
    PERFORM get_cell_value USING <ls_raw>  1 CHANGING ls_out-material.
    PERFORM get_cell_value USING <ls_raw>  2 CHANGING ls_out-centro.
    PERFORM get_cell_value USING <ls_raw>  3 CHANGING ls_out-grupo_compras.
    PERFORM get_cell_value USING <ls_raw>  4 CHANGING ls_out-tipo_mrp.
    PERFORM get_cell_value USING <ls_raw>  5 CHANGING ls_out-plazo_entrega.
    PERFORM get_cell_value USING <ls_raw>  6 CHANGING ls_out-tipo_aprov.
    PERFORM get_cell_value USING <ls_raw>  7 CHANGING ls_out-grupo_carga.
    PERFORM get_cell_value USING <ls_raw>  8 CHANGING ls_out-verif_disponib.
    PERFORM get_cell_value USING <ls_raw>  9 CHANGING ls_out-centro_beneficio.
    PERFORM get_cell_value USING <ls_raw> 10 CHANGING ls_out-pais_origen.
    PERFORM get_cell_value USING <ls_raw> 11 CHANGING ls_out-perfil_distrib.
    PERFORM get_cell_value USING <ls_raw> 12 CHANGING ls_out-stock_negativo.
    PERFORM get_cell_value USING <ls_raw> 13 CHANGING ls_out-fuente_aprov.
    PERFORM get_cell_value USING <ls_raw> 14 CHANGING ls_out-valor_redondeo.

    IF ls_out-material IS INITIAL AND ls_out-centro IS INITIAL.
      CONTINUE.
    ENDIF.

    APPEND ls_out TO lt_out.
  ENDLOOP.

  ct_data = lt_out.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  FILL_ALMACENES  (hoja 03_ALMACENES: 3 columnas)
*&---------------------------------------------------------------------*
FORM fill_almacenes USING it_raw TYPE STANDARD TABLE
                    CHANGING ct_data TYPE any TABLE.

  FIELD-SYMBOLS: <ls_raw> TYPE any.
  DATA: lv_idx TYPE i,
        ls_out TYPE gty_s_almacen,
        lt_out TYPE gtt_almacen.

  LOOP AT it_raw ASSIGNING <ls_raw>.
    lv_idx = sy-tabix.
    IF lv_idx < gc_first_data_row.
      CONTINUE.
    ENDIF.

    CLEAR ls_out.
    ls_out-row = lv_idx.
    PERFORM get_cell_value USING <ls_raw> 1 CHANGING ls_out-material.
    PERFORM get_cell_value USING <ls_raw> 2 CHANGING ls_out-centro.
    PERFORM get_cell_value USING <ls_raw> 3 CHANGING ls_out-almacen.

    IF ls_out-material IS INITIAL AND ls_out-centro IS INITIAL.
      CONTINUE.
    ENDIF.

    APPEND ls_out TO lt_out.
  ENDLOOP.

  ct_data = lt_out.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  FILL_VALORACION  (hoja 06_VALORACION: 7 columnas)
*&---------------------------------------------------------------------*
FORM fill_valoracion USING it_raw TYPE STANDARD TABLE
                     CHANGING ct_data TYPE any TABLE.

  FIELD-SYMBOLS: <ls_raw> TYPE any.
  DATA: lv_idx TYPE i,
        ls_out TYPE gty_s_valoracion,
        lt_out TYPE gtt_valoracion.

  LOOP AT it_raw ASSIGNING <ls_raw>.
    lv_idx = sy-tabix.
    IF lv_idx < gc_first_data_row.
      CONTINUE.
    ENDIF.

    CLEAR ls_out.
    ls_out-row = lv_idx.
    PERFORM get_cell_value USING <ls_raw> 1 CHANGING ls_out-material.
    PERFORM get_cell_value USING <ls_raw> 2 CHANGING ls_out-area_valoracion.
    PERFORM get_cell_value USING <ls_raw> 3 CHANGING ls_out-clase_valoracion.
    PERFORM get_cell_value USING <ls_raw> 4 CHANGING ls_out-control_precio.
    PERFORM get_cell_value USING <ls_raw> 5 CHANGING ls_out-precio_promedio.
    PERFORM get_cell_value USING <ls_raw> 6 CHANGING ls_out-precio_estandar.
    PERFORM get_cell_value USING <ls_raw> 7 CHANGING ls_out-unidad_precio.

    IF ls_out-material IS INITIAL AND ls_out-area_valoracion IS INITIAL.
      CONTINUE.
    ENDIF.

    APPEND ls_out TO lt_out.
  ENDLOOP.

  ct_data = lt_out.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  FILL_VENTAS  (hoja 07_VENTAS_POS: 9 columnas)
*&---------------------------------------------------------------------*
FORM fill_ventas USING it_raw TYPE STANDARD TABLE
                 CHANGING ct_data TYPE any TABLE.

  FIELD-SYMBOLS: <ls_raw> TYPE any.
  DATA: lv_idx TYPE i,
        ls_out TYPE gty_s_ventas,
        lt_out TYPE gtt_ventas.

  LOOP AT it_raw ASSIGNING <ls_raw>.
    lv_idx = sy-tabix.
    IF lv_idx < gc_first_data_row.
      CONTINUE.
    ENDIF.

    CLEAR ls_out.
    ls_out-row = lv_idx.
    PERFORM get_cell_value USING <ls_raw> 1 CHANGING ls_out-material.
    PERFORM get_cell_value USING <ls_raw> 2 CHANGING ls_out-org_ventas.
    PERFORM get_cell_value USING <ls_raw> 3 CHANGING ls_out-canal_distrib.
    PERFORM get_cell_value USING <ls_raw> 4 CHANGING ls_out-categoria_item.
    PERFORM get_cell_value USING <ls_raw> 5 CHANGING ls_out-grupo_imputacion.
    PERFORM get_cell_value USING <ls_raw> 6 CHANGING ls_out-fecha_inicio.
    PERFORM get_cell_value USING <ls_raw> 7 CHANGING ls_out-fecha_fin.
    PERFORM get_cell_value USING <ls_raw> 8 CHANGING ls_out-material_ref_precio.
    PERFORM get_cell_value USING <ls_raw> 9 CHANGING ls_out-unidad_entrega.

    IF ls_out-material IS INITIAL AND ls_out-org_ventas IS INITIAL.
      CONTINUE.
    ENDIF.

    APPEND ls_out TO lt_out.
  ENDLOOP.

  ct_data = lt_out.

ENDFORM.
