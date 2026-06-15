*&---------------------------------------------------------------------*
*& Include          ZR_ALLOC_TABLE_GEN_0785_CLS
*& Clase local: lógica de generación masiva de Tablas de Asignación
*& Referencia: EF D136A - Tablas de Asignación
*&---------------------------------------------------------------------*

CLASS lcl_alloc_table_gen DEFINITION.

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

    "! Convierte un mensaje devuelto por WRF_AT_GENERATE_ALLOCATION en texto legible.
    METHODS get_message_text
      IMPORTING
        i_message TYPE smesg
      RETURNING
        VALUE(r_text) TYPE string.

ENDCLASS.



CLASS lcl_alloc_table_gen IMPLEMENTATION.

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

    " Columnas esperadas del layout (ver EF D136A):
    " 1 Proveedor | 2 Fecha Entrega | 3 Org. Compras | 4 Grupo de Compras |
    " 5 Centro Suministrador | 6 Material | 7 Centro Destino | 8 Cantidad | 9 UoM
    CONSTANTS: c_first_col TYPE i VALUE 1,
               c_last_col  TYPE i VALUE 9,
               c_first_row TYPE i VALUE 2,
               c_last_row  TYPE i VALUE 99999.

    DATA lt_excel TYPE TABLE OF alsmex_tabline.

    CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
      EXPORTING
        filename                = file_path
        i_begin_col             = c_first_col
        i_begin_row             = c_first_row
        i_end_col               = c_last_col
        i_end_row               = c_last_row
      TABLES
        intern                  = lt_excel
      EXCEPTIONS
        inconsistent_parameters = 1
        upload_ole              = 2
        OTHERS                  = 3.

    IF sy-subrc <> 0.
      MESSAGE 'El archivo no tiene un formato Excel válido o no fue posible leerlo'
        TYPE 'I' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    IF lt_excel IS INITIAL.
      MESSAGE 'El archivo no contiene registros para procesar' TYPE 'I' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    SORT lt_excel BY row col.

    LOOP AT lt_excel INTO DATA(ls_cell).

      AT NEW row.
        APPEND VALUE ty_excel_row( row_num = ls_cell-row - ( c_first_row - 1 ) ) TO excel_data.
      ENDAT.

      ASSIGN excel_data[ lines( excel_data ) ] TO FIELD-SYMBOL(<fs_row>).

      CASE ls_cell-col.
        WHEN 1.
          <fs_row>-lifnr = ls_cell-value.
        WHEN 2.
          " Fecha de Entrega: formato DD/MM/AAAA
          IF strlen( ls_cell-value ) = 10.
            <fs_row>-eindt = |{ ls_cell-value+6(4) }{ ls_cell-value+3(2) }{ ls_cell-value+0(2) }|.
          ENDIF.
        WHEN 3.
          <fs_row>-ekorg = ls_cell-value.
        WHEN 4.
          <fs_row>-ekgrp = ls_cell-value.
        WHEN 5.
          <fs_row>-werks_sup = ls_cell-value.
        WHEN 6.
          <fs_row>-matnr = ls_cell-value.
        WHEN 7.
          <fs_row>-werks_rec = ls_cell-value.
        WHEN 8.
          " Cantidad: admite coma o punto como separador decimal
          DATA(lv_qty_text) = ls_cell-value.
          REPLACE ALL OCCURRENCES OF ',' IN lv_qty_text WITH '.'.
          TRY.
              <fs_row>-menge = lv_qty_text.
            CATCH cx_root.
              CLEAR <fs_row>-menge.
          ENDTRY.
        WHEN 9.
          <fs_row>-meins = ls_cell-value.
      ENDCASE.

    ENDLOOP.

    r_success = abap_true.

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
    " Construcción del "pedido virtual" (estructuras tipo EKKO/EKPO/EKET)
    " requerido por WRF_AT_GENERATE_ALLOCATION, según firma confirmada en
    " SE37 (ver EF D136A, "Información técnica").
    "
    " EBELN es un identificador interno generado por este programa (no
    " corresponde a un documento de compras real) y se usa únicamente para
    " correlacionar las posiciones enviadas con ET_REFERENCES al recibir
    " el resultado.
    " -----------------------------------------------------------------------
    DATA(ls_first_line) = i_lines[ 1 ].
    DATA(lv_ebeln) = |{ i_group_id WIDTH = 10 ALIGN = RIGHT PAD = '0' }|.

    DATA lt_ekko_ok    TYPE wrf_ekko_ok_tty.
    DATA lt_ekpo       TYPE wrf_at_ekpo_tty.
    DATA lt_eket       TYPE wrf_at_eket_tty.
    DATA lt_po_data    TYPE wrf_po_data_tty.
    DATA lt_messages   TYPE tsmesg.
    DATA lt_references TYPE wrf_references_tty.
    DATA lv_lines_actual TYPE i.
    DATA lv_last_abeln   TYPE abeln.

    APPEND VALUE #( ebeln = lv_ebeln
                    fixpo = abap_false
                    lifnr = ls_first_line-lifnr ) TO lt_ekko_ok.

    LOOP AT i_lines INTO DATA(ls_item_line).

      DATA(lv_ebelp) = CONV ebelp( sy-tabix * 10 ).

      APPEND VALUE #( ebeln = lv_ebeln
                      ebelp = lv_ebelp
                      matnr = ls_item_line-matnr
                      werks = ls_item_line-werks_rec
                      menge = ls_item_line-menge
                      meins = ls_item_line-meins ) TO lt_ekpo.

      APPEND VALUE #( ebeln = lv_ebeln
                      ebelp = lv_ebelp
                      etenr = '0001'
                      eindt = ls_item_line-eindt
                      menge = ls_item_line-menge ) TO lt_eket.

      APPEND VALUE #( ebeln    = lv_ebeln
                      ebelp    = lv_ebelp
                      lifnr    = ls_item_line-lifnr
                      matnr    = ls_item_line-matnr
                      eindt    = ls_item_line-eindt
                      ekorg    = ls_item_line-ekorg
                      ekgrp    = ls_item_line-ekgrp
                      dc       = ls_item_line-werks_sup
                      act_quan = ls_item_line-menge
                      unit     = ls_item_line-meins
                      act_unit = ls_item_line-meins
                      aurel    = abap_true ) TO lt_po_data.

    ENDLOOP.

    " ---------------------------------------------------------------------
    " Parámetros de configuración del FM (tipo de Tabla de Asignación,
    " estrategia de asignación, etc.). Se utilizan valores "dummy" como
    " marcador de posición: deben confirmarse/ajustarse en Diseño Técnico
    " contra la configuración real (T620 y customizing de Tablas de
    " Asignación) del sistema destino.
    " ---------------------------------------------------------------------
    CONSTANTS: gc_aufar TYPE aufar     VALUE '01',
               gc_astra TYPE astra     VALUE '01',
               gc_astva TYPE astra_var VALUE '01',
               gc_aufme TYPE wrf_aufme VALUE 'EA'.

    DATA ls_t620 TYPE t620.

    CALL FUNCTION 'WRF_AT_GENERATE_ALLOCATION'
      EXPORTING
        it_po_data       = lt_po_data
        it_ekko_ok       = lt_ekko_ok
        it_eket          = lt_eket
        it_ekpo          = lt_ekpo
        i_t620           = ls_t620
        i_aufar          = gc_aufar
        i_astra          = gc_astra
        i_astva          = gc_astva
        i_aufme          = gc_aufme
        i_hk_cb          = abap_false
        i_po_cb          = abap_false
      IMPORTING
        et_collected_msg = lt_messages
        e_lines_actual   = lv_lines_actual
        et_references    = lt_references
        e_last_abeln     = lv_last_abeln.

    DATA(lv_has_error) = abap_false.
    LOOP AT lt_messages INTO DATA(ls_error_msg) WHERE msgty = 'E' OR msgty = 'A'.
      lv_has_error = abap_true.
      EXIT.
    ENDLOOP.

    DATA(lv_message_text) = COND string(
      WHEN lt_messages IS NOT INITIAL THEN get_message_text( lt_messages[ 1 ] )
      WHEN lv_has_error = abap_false THEN 'Generado correctamente'
      ELSE 'Error desconocido al generar la Tabla de Asignación' ).

    IF lv_has_error = abap_false AND lv_last_abeln IS NOT INITIAL.
      c_header-alloc_table = lv_last_abeln.
      c_header-status      = 'Exitosa'.
    ELSE.
      c_header-status      = 'Error'.
    ENDIF.

    LOOP AT i_lines INTO DATA(ls_result_line).

      DATA(lv_result_ebelp) = CONV ebelp( sy-tabix * 10 ).

      READ TABLE lt_references INTO DATA(ls_reference)
        WITH KEY ebeln = lv_ebeln ebelp = lv_result_ebelp.

      IF sy-subrc = 0 AND lv_has_error = abap_false.
        APPEND VALUE ty_result_detail(
          group_id    = i_group_id
          alloc_table = ls_reference-abeln
          matnr       = ls_result_line-matnr
          werks_rec   = ls_result_line-werks_rec
          menge       = ls_result_line-menge
          meins       = ls_result_line-meins
          result      = 'OK'
          message     = lv_message_text ) TO c_details.
        c_header-success_recs = c_header-success_recs + 1.
      ELSE.
        APPEND VALUE ty_result_detail(
          group_id    = i_group_id
          alloc_table = COND #( WHEN sy-subrc = 0 THEN ls_reference-abeln ELSE space )
          matnr       = ls_result_line-matnr
          werks_rec   = ls_result_line-werks_rec
          menge       = ls_result_line-menge
          meins       = ls_result_line-meins
          result      = 'ERROR'
          message     = lv_message_text ) TO c_details.
        c_header-error_recs = c_header-error_recs + 1.
      ENDIF.

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


  METHOD get_message_text.

    r_text = i_message-text.

  ENDMETHOD.

ENDCLASS.
