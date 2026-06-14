CLASS zcl_alloc_table_gen_0785 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    " Línea del archivo Excel cargado (1:1 con el layout solicitado)
    TYPES: BEGIN OF ty_excel_row,
             row_num   TYPE i,
             lifnr     TYPE lifnr,      " Proveedor
             eindt     TYPE dats,       " Fecha de Entrega
             ekorg     TYPE ekorg,      " Organización de Compras
             ekgrp     TYPE ekgrp,      " Grupo de Compras
             werks_sup TYPE werks_d,    " Centro Suministrador
             matnr     TYPE matnr,      " Material
             werks_rec TYPE werks_d,    " Centro Destino
             menge     TYPE menge_d,    " Cantidad
             meins     TYPE meins,      " Unidad de Medida
           END OF ty_excel_row.
    TYPES ty_excel_rows TYPE STANDARD TABLE OF ty_excel_row WITH EMPTY KEY.

    " Errores detectados durante la validación funcional del Excel
    TYPES: BEGIN OF ty_validation_error,
             row_num TYPE i,
             message TYPE string,
           END OF ty_validation_error.
    TYPES ty_validation_errors TYPE STANDARD TABLE OF ty_validation_error WITH EMPTY KEY.

    " ALV Cabecera: resumen por Tabla de Asignación generada
    TYPES: BEGIN OF ty_result_header,
             group_id     TYPE i,
             lifnr        TYPE lifnr,
             eindt        TYPE dats,
             ekorg        TYPE ekorg,
             alloc_table  TYPE char10,
             total_recs   TYPE i,
             success_recs TYPE i,
             error_recs   TYPE i,
             status       TYPE char20,
           END OF ty_result_header.
    TYPES ty_result_headers TYPE STANDARD TABLE OF ty_result_header WITH EMPTY KEY.

    " ALV Detalle: resultado por cada registro procesado
    TYPES: BEGIN OF ty_result_detail,
             group_id    TYPE i,
             alloc_table TYPE char10,
             matnr       TYPE matnr,
             werks_rec   TYPE werks_d,
             menge       TYPE menge_d,
             meins       TYPE meins,
             result      TYPE char6,
             message     TYPE string,
           END OF ty_result_detail.
    TYPES ty_result_details TYPE STANDARD TABLE OF ty_result_detail WITH EMPTY KEY.

    METHODS constructor
      IMPORTING
        i_file_path  TYPE string
        i_simulation TYPE abap_bool.

    "! Orquesta el proceso completo: carga, validación, agrupación,
    "! generación de tablas de asignación y despliegue de resultados.
    METHODS process.

  PRIVATE SECTION.

    DATA file_path  TYPE string.
    DATA simulation TYPE abap_bool.
    DATA excel_data TYPE ty_excel_rows.
    DATA val_errors TYPE ty_validation_errors.
    DATA result_hdr TYPE ty_result_headers.
    DATA result_det TYPE ty_result_details.

    "! Carga el Excel a una tabla interna con la misma estructura del layout.
    "! @parameter r_success | 'X' si el archivo se pudo leer y convertir.
    METHODS upload_excel
      RETURNING VALUE(r_success) TYPE abap_bool.

    "! Convierte una línea de texto (celdas separadas por tabulador) a ty_excel_row.
    METHODS parse_excel_line
      IMPORTING
        i_row_num TYPE i
        i_line    TYPE string
      RETURNING
        VALUE(r_row) TYPE ty_excel_row.

    "! Ejecuta todas las validaciones funcionales sobre excel_data.
    METHODS validate_data.

    METHODS add_validation_error
      IMPORTING
        i_row_num TYPE i
        i_message TYPE string.

    METHODS check_master_data
      IMPORTING
        i_row TYPE ty_excel_row.

    METHODS check_duplicates.

    METHODS check_group_consistency.

    "! Muestra todos los errores de validación en una ventana emergente
    "! y finaliza el procesamiento (sin generar tablas de asignación).
    METHODS show_validation_errors.

    "! Agrupa los registros válidos por Proveedor / Fecha de Entrega / Org. Compras
    "! y genera una Tabla de Asignación por cada grupo.
    METHODS process_groups.

    "! Genera (o simula) la Tabla de Asignación de un grupo, llamando al
    "! módulo estándar WRF_AT_GENERATE_ALLOCATION.
    METHODS generate_allocation_table
      IMPORTING
        i_group_id TYPE i
        i_lines    TYPE ty_excel_rows
      CHANGING
        c_header   TYPE ty_result_header
        c_details  TYPE ty_result_details.

    "! Despliega el ALV de 2 niveles (cabecera / detalle) con el resultado final.
    METHODS display_results.

ENDCLASS.



CLASS zcl_alloc_table_gen_0785 IMPLEMENTATION.

  METHOD constructor.
    file_path  = i_file_path.
    simulation = i_simulation.
  ENDMETHOD.


  METHOD process.

    IF upload_excel( ) = abap_false.
      RETURN.
    ENDIF.

    validate_data( ).

    IF val_errors IS NOT INITIAL.
      show_validation_errors( ).
      RETURN.
    ENDIF.

    process_groups( ).

    display_results( ).

  ENDMETHOD.


  METHOD upload_excel.

    r_success = abap_false.

    IF file_path IS INITIAL.
      MESSAGE 'Debe indicar el archivo Excel a procesar' TYPE 'I' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    DATA lt_raw_data TYPE solix_tab.
    DATA lv_size     TYPE i.
    DATA lv_xstring  TYPE xstring.
    DATA lt_lines    TYPE truxs_t_text_data.

    cl_gui_frontend_services=>gui_upload(
      EXPORTING
        filename   = file_path
        filetype   = 'BIN'
      IMPORTING
        filelength = lv_size
      CHANGING
        data_tab   = lt_raw_data
      EXCEPTIONS
        OTHERS     = 1 ).

    IF sy-subrc <> 0.
      MESSAGE 'No fue posible leer el archivo seleccionado' TYPE 'I' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    TRY.
        lv_xstring = cl_bcs_convert=>solix_to_xstring(
                        it_solix = lt_raw_data
                        iv_size  = lv_size ).

        DATA(lo_excel) = NEW cl_fdt_xl_spreadsheet(
                                document_name = file_path
                                xdocument     = lv_xstring ).

        DATA(lt_worksheets) = lo_excel->if_fdt_doc_spreadsheet~get_worksheet_names( ).

        lo_excel->if_fdt_doc_spreadsheet~get_itab_from_worksheet(
          EXPORTING
            worksheet = lt_worksheets[ 1 ]
          IMPORTING
            itab      = lt_lines ).

      CATCH cx_root INTO DATA(lx_error).
        MESSAGE |El archivo no tiene un formato Excel válido: { lx_error->get_text( ) }|
          TYPE 'I' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.

    IF lines( lt_lines ) < 2.
      MESSAGE 'El archivo no contiene registros para procesar' TYPE 'I' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    " La primera línea es el encabezado de columnas (se omite)
    LOOP AT lt_lines INTO DATA(lv_line) FROM 2.
      APPEND parse_excel_line( i_row_num = sy-tabix - 1
                                i_line    = lv_line ) TO excel_data.
    ENDLOOP.

    r_success = abap_true.

  ENDMETHOD.


  METHOD parse_excel_line.

    SPLIT i_line AT cl_abap_char_utilities=>horizontal_tab INTO TABLE DATA(lt_fields).

    r_row-row_num = i_row_num.

    r_row-lifnr     = COND lifnr(     WHEN lines( lt_fields ) >= 1 THEN lt_fields[ 1 ] ).
    r_row-ekorg     = COND ekorg(     WHEN lines( lt_fields ) >= 3 THEN lt_fields[ 3 ] ).
    r_row-ekgrp     = COND ekgrp(     WHEN lines( lt_fields ) >= 4 THEN lt_fields[ 4 ] ).
    r_row-werks_sup = COND werks_d(   WHEN lines( lt_fields ) >= 5 THEN lt_fields[ 5 ] ).
    r_row-matnr     = COND matnr(     WHEN lines( lt_fields ) >= 6 THEN lt_fields[ 6 ] ).
    r_row-werks_rec = COND werks_d(   WHEN lines( lt_fields ) >= 7 THEN lt_fields[ 7 ] ).
    r_row-meins     = COND meins(     WHEN lines( lt_fields ) >= 9 THEN lt_fields[ 9 ] ).

    " Fecha de Entrega: formato DD/MM/AAAA
    IF lines( lt_fields ) >= 2 AND strlen( lt_fields[ 2 ] ) = 10.
      DATA(lv_date_text) = lt_fields[ 2 ].
      r_row-eindt = |{ lv_date_text+6(4) }{ lv_date_text+3(2) }{ lv_date_text+0(2) }|.
    ENDIF.

    " Cantidad: admite coma o punto como separador decimal
    IF lines( lt_fields ) >= 8.
      DATA(lv_qty_text) = lt_fields[ 8 ].
      REPLACE ALL OCCURRENCES OF ',' IN lv_qty_text WITH '.'.
      TRY.
          r_row-menge = lv_qty_text.
        CATCH cx_root.
          CLEAR r_row-menge.
      ENDTRY.
    ENDIF.

  ENDMETHOD.


  METHOD validate_data.

    CLEAR val_errors.

    LOOP AT excel_data INTO DATA(ls_row).

      " Validación: campos completos
      IF ls_row-lifnr IS INITIAL OR ls_row-eindt IS INITIAL OR ls_row-ekorg IS INITIAL
        OR ls_row-ekgrp IS INITIAL OR ls_row-werks_sup IS INITIAL OR ls_row-matnr IS INITIAL
        OR ls_row-werks_rec IS INITIAL OR ls_row-meins IS INITIAL.
        add_validation_error( i_row_num = ls_row-row_num
                               i_message = 'Existen campos sin completar' ).
        CONTINUE.
      ENDIF.

      " Validación: cantidad > 0
      IF ls_row-menge <= 0.
        add_validation_error( i_row_num = ls_row-row_num
                               i_message = |Cantidad inválida: { ls_row-menge }| ).
        CONTINUE.
      ENDIF.

      " Validación: datos maestros existentes
      check_master_data( ls_row ).

    ENDLOOP.

    " Validación: sin duplicados
    check_duplicates( ).

    " Validación: consistencia dentro del grupo
    check_group_consistency( ).

  ENDMETHOD.


  METHOD add_validation_error.
    APPEND VALUE ty_validation_error( row_num = i_row_num
                                       message = i_message ) TO val_errors.
  ENDMETHOD.


  METHOD check_master_data.

    SELECT SINGLE lifnr FROM lfa1 INTO @DATA(lv_lifnr) WHERE lifnr = @i_row-lifnr.
    IF sy-subrc <> 0.
      add_validation_error( i_row_num = i_row-row_num
                             i_message = |Proveedor { i_row-lifnr } no existe| ).
    ENDIF.

    SELECT SINGLE matnr FROM mara INTO @DATA(lv_matnr) WHERE matnr = @i_row-matnr.
    IF sy-subrc <> 0.
      add_validation_error( i_row_num = i_row-row_num
                             i_message = |Material { i_row-matnr } no existe| ).
    ENDIF.

    SELECT SINGLE werks FROM t001w INTO @DATA(lv_werks_rec) WHERE werks = @i_row-werks_rec.
    IF sy-subrc <> 0.
      add_validation_error( i_row_num = i_row-row_num
                             i_message = |Centro Destino { i_row-werks_rec } no existe| ).
    ENDIF.

    SELECT SINGLE werks FROM t001w INTO @DATA(lv_werks_sup) WHERE werks = @i_row-werks_sup.
    IF sy-subrc <> 0.
      add_validation_error( i_row_num = i_row-row_num
                             i_message = |Centro Suministrador { i_row-werks_sup } no existe| ).
    ENDIF.

    SELECT SINGLE ekorg FROM t024e INTO @DATA(lv_ekorg) WHERE ekorg = @i_row-ekorg.
    IF sy-subrc <> 0.
      add_validation_error( i_row_num = i_row-row_num
                             i_message = |Organización de Compras { i_row-ekorg } no existe| ).
    ENDIF.

    SELECT SINGLE ekgrp FROM t024 INTO @DATA(lv_ekgrp) WHERE ekgrp = @i_row-ekgrp.
    IF sy-subrc <> 0.
      add_validation_error( i_row_num = i_row-row_num
                             i_message = |Grupo de Compras { i_row-ekgrp } no existe| ).
    ENDIF.

    SELECT SINGLE msehi FROM t006 INTO @DATA(lv_meins) WHERE msehi = @i_row-meins.
    IF sy-subrc <> 0.
      add_validation_error( i_row_num = i_row-row_num
                             i_message = |Unidad de Medida { i_row-meins } no existe| ).
    ENDIF.

  ENDMETHOD.


  METHOD check_duplicates.

    DATA lt_check TYPE ty_excel_rows.

    LOOP AT excel_data INTO DATA(ls_row).

      DATA(lv_found) = abap_false.

      LOOP AT lt_check INTO DATA(ls_check)
        WHERE lifnr     = ls_row-lifnr
          AND eindt     = ls_row-eindt
          AND ekorg     = ls_row-ekorg
          AND ekgrp     = ls_row-ekgrp
          AND werks_sup = ls_row-werks_sup
          AND matnr     = ls_row-matnr
          AND werks_rec = ls_row-werks_rec
          AND menge     = ls_row-menge
          AND meins     = ls_row-meins.
        lv_found = abap_true.
        EXIT.
      ENDLOOP.

      IF lv_found = abap_true.
        add_validation_error( i_row_num = ls_row-row_num
                               i_message = 'Registro duplicado' ).
      ELSE.
        APPEND ls_row TO lt_check.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD check_group_consistency.

    " Dentro de una misma clave de agrupación (Proveedor / Fecha Entrega / Org. Compras),
    " el Grupo de Compras y el Centro Suministrador deben ser únicos, ya que la cabecera
    " de la Tabla de Asignación solo admite un valor para cada uno.
    DATA(lt_sorted) = excel_data.
    SORT lt_sorted BY lifnr eindt ekorg.

    LOOP AT lt_sorted INTO DATA(ls_row).

      AT NEW ekorg.
        DATA(ls_first) = ls_row.
      ENDAT.

      IF ls_row-ekgrp <> ls_first-ekgrp OR ls_row-werks_sup <> ls_first-werks_sup.
        add_validation_error(
          i_row_num = ls_row-row_num
          i_message = |Grupo de Compras y Centro Suministrador deben ser consistentes |
                    && |para el grupo { ls_row-lifnr } / { ls_row-eindt DATE = USER } / { ls_row-ekorg }| ).
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD show_validation_errors.

    DATA(lv_message) = |Se encontraron { lines( val_errors ) } error(es) en el archivo:|
                     && cl_abap_char_utilities=>newline.

    LOOP AT val_errors INTO DATA(ls_error).
      lv_message = lv_message
                 && |Fila { ls_error-row_num }: { ls_error-message }|
                 && cl_abap_char_utilities=>newline.
    ENDLOOP.

    MESSAGE lv_message TYPE 'I' DISPLAY LIKE 'E'.

  ENDMETHOD.


  METHOD process_groups.

    DATA(lt_sorted) = excel_data.
    SORT lt_sorted BY lifnr eindt ekorg.

    DATA lv_group_id TYPE i VALUE 0.
    DATA lt_group_lines TYPE ty_excel_rows.

    LOOP AT lt_sorted INTO DATA(ls_row).

      AT NEW ekorg.
        lv_group_id = lv_group_id + 1.
        CLEAR lt_group_lines.
      ENDAT.

      APPEND ls_row TO lt_group_lines.

      AT END OF ekorg.
        DATA(ls_header) = VALUE ty_result_header(
          group_id = lv_group_id
          lifnr    = ls_row-lifnr
          eindt    = ls_row-eindt
          ekorg    = ls_row-ekorg ).

        DATA(lt_details) = VALUE ty_result_details( ).

        generate_allocation_table(
          EXPORTING
            i_group_id = lv_group_id
            i_lines    = lt_group_lines
          CHANGING
            c_header   = ls_header
            c_details  = lt_details ).

        APPEND ls_header TO result_hdr.
        APPEND LINES OF lt_details TO result_det.
      ENDAT.

    ENDLOOP.

  ENDMETHOD.


  METHOD generate_allocation_table.

    c_header-total_recs = lines( i_lines ).

    IF simulation = abap_true.

      c_header-status       = 'Simulación'.
      c_header-success_recs = c_header-total_recs.
      c_header-error_recs   = 0.

      LOOP AT i_lines INTO DATA(ls_sim_line).
        APPEND VALUE ty_result_detail(
          group_id  = i_group_id
          matnr     = ls_sim_line-matnr
          werks_rec = ls_sim_line-werks_rec
          menge     = ls_sim_line-menge
          meins     = ls_sim_line-meins
          result    = 'OK'
          message   = 'Simulación: registro válido' ) TO c_details.
      ENDLOOP.

      RETURN.
    ENDIF.

    " -----------------------------------------------------------------------
    " Construcción de la cabecera y posiciones para WRF_AT_GENERATE_ALLOCATION.
    " Los nombres de estructuras/parámetros deben confirmarse en SE37 contra
    " la versión instalada (ver sección "Información técnica" de la EF D136A).
    " -----------------------------------------------------------------------
    DATA(ls_first_line) = i_lines[ 1 ].

    DATA ls_fm_header TYPE wrf_at_header.
    DATA lt_fm_items  TYPE wrf_at_item_tt.
    DATA lv_alloc_no  TYPE wrf_at_alloc_no.
    DATA lt_return    TYPE bapiret2_t.

    ls_fm_header-lifnr = ls_first_line-lifnr.     " Supplier
    ls_fm_header-ekorg = ls_first_line-ekorg.     " Purchasing Organization
    ls_fm_header-ekgrp = ls_first_line-ekgrp.     " Purchasing Group
    ls_fm_header-werks = ls_first_line-werks_sup. " Supply Plant
    ls_fm_header-eindt = ls_first_line-eindt.     " Valid From

    LOOP AT i_lines INTO DATA(ls_item_line).
      APPEND VALUE #( matnr = ls_item_line-matnr
                      werks = ls_item_line-werks_rec
                      menge = ls_item_line-menge
                      meins = ls_item_line-meins ) TO lt_fm_items.
    ENDLOOP.

    CALL FUNCTION 'WRF_AT_GENERATE_ALLOCATION'
      EXPORTING
        is_header        = ls_fm_header
        it_items         = lt_fm_items
      IMPORTING
        e_alloc_table_no = lv_alloc_no
      TABLES
        et_return        = lt_return.

    DATA(lv_has_error) = abap_false.
    LOOP AT lt_return INTO DATA(ls_return) WHERE type = 'E' OR type = 'A'.
      lv_has_error = abap_true.
      EXIT.
    ENDLOOP.

    IF lv_has_error = abap_false.
      c_header-alloc_table  = lv_alloc_no.
      c_header-status       = 'Exitosa'.
      c_header-success_recs = c_header-total_recs.
      c_header-error_recs   = 0.
    ELSE.
      c_header-status       = 'Error'.
      c_header-success_recs = 0.
      c_header-error_recs   = c_header-total_recs.
    ENDIF.

    DATA(lv_message_text) = COND string(
      WHEN lt_return IS NOT INITIAL THEN lt_return[ 1 ]-message
      WHEN lv_has_error = abap_false THEN 'Generado correctamente'
      ELSE 'Error desconocido al generar la Tabla de Asignación' ).

    LOOP AT i_lines INTO DATA(ls_result_line).
      APPEND VALUE ty_result_detail(
        group_id    = i_group_id
        alloc_table = c_header-alloc_table
        matnr       = ls_result_line-matnr
        werks_rec   = ls_result_line-werks_rec
        menge       = ls_result_line-menge
        meins       = ls_result_line-meins
        result      = COND char6( WHEN lv_has_error = abap_false THEN 'OK' ELSE 'ERROR' )
        message     = lv_message_text ) TO c_details.
    ENDLOOP.

  ENDMETHOD.


  METHOD display_results.

    TRY.
        DATA(lt_binding) = VALUE salv_t_hierseq_binding_info(
          ( level1 = 'GROUP_ID' level2 = 'GROUP_ID' ) ).

        cl_salv_hierseq_table=>factory(
          EXPORTING
            t_binding_level1_level2 = lt_binding
          IMPORTING
            r_hierseq                = DATA(lo_alv)
          CHANGING
            t_table                  = result_hdr
            t_table2                 = result_det ).

        DATA(lo_header_cols) = lo_alv->get_columns( )->get_level1_columns( ).
        DATA(lo_detail_cols) = lo_alv->get_columns( )->get_level2_columns( ).

        lo_header_cols->set_optimize( abap_true ).
        lo_detail_cols->set_optimize( abap_true ).

        TRY.
            lo_header_cols->get_column( 'GROUP_ID' )->set_technical( abap_true ).
            lo_detail_cols->get_column( 'GROUP_ID' )->set_technical( abap_true ).
          CATCH cx_salv_not_found.
        ENDTRY.

        lo_alv->display( ).

      CATCH cx_root INTO DATA(lx_error).
        MESSAGE |No fue posible mostrar el resultado: { lx_error->get_text( ) }|
          TYPE 'I' DISPLAY LIKE 'E'.
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
