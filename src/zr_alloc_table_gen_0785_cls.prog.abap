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

    "! Extrae el texto del primer mensaje de error devuelto por el FM.
    METHODS get_message_text
      IMPORTING
        it_messages TYPE rfc_alloc_messages_out_tty
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

    DATA(ls_first) = i_lines[ 1 ].

    " -----------------------------------------------------------------------
    " Cabecera de la Tabla de Asignación
    " -----------------------------------------------------------------------
    DATA ls_header TYPE rfc_alloc_header_in.

    ls_header-aufar = 'ZTEM'.                    " Clase tabla asignación (constante)
    ls_header-vzwrk = ls_first-werks_sup.        " Centro Suministrador
    ls_header-ekorg = ls_first-ekorg.            " Organización de Compras
    ls_header-ekgrp = ls_first-ekgrp.            " Grupo de Compras
    ls_header-ervon = 'A'.                       " Aplicación creadora (constante)
    ls_header-bezch = |TABLA ASIGNACION { ls_first-eindt+6(2) }{ ls_first-eindt+4(2) }{ ls_first-eindt(4) }|.

    " -----------------------------------------------------------------------
    " Items: un registro por cada MATNR único dentro del grupo.
    " ABELP se asigna de forma incremental (00010, 00020, ...).
    " -----------------------------------------------------------------------
    DATA lt_items    TYPE rfc_alloc_items_in_20_tty.
    DATA lv_item_pos TYPE abelp.

    LOOP AT i_lines INTO DATA(ls_line).
      IF NOT line_exists( lt_items[ matnr = ls_line-matnr ] ).
        lv_item_pos = lv_item_pos + 10.
        APPEND VALUE #( abelp = lv_item_pos
                        vzwrk = ls_line-werks_sup
                        matnr = ls_line-matnr
                        wedat = ls_line-eindt
                        aufme = ls_line-meins
                        attyp = '02'
                        meins = ls_line-meins ) TO lt_items.
      ENDIF.
    ENDLOOP.

    " -----------------------------------------------------------------------
    " Tiendas destino: un registro por cada línea del Excel.
    " ABELF es incremental por cada ABELP (por material).
    " -----------------------------------------------------------------------
    DATA lt_stores TYPE rfc_alloc_stores_in_20_tty.
    DATA lv_abelf  TYPE abelp.

    LOOP AT lt_items INTO DATA(ls_item).
      CLEAR lv_abelf.
      LOOP AT i_lines INTO DATA(ls_store) WHERE matnr = ls_item-matnr.
        lv_abelf = lv_abelf + 10.
        APPEND VALUE #( abelp       = ls_item-abelp
                        abelf       = lv_abelf
                        fiwrk       = ls_store-werks_rec
                        lfdat       = ls_store-eindt
                        pmngu       = ls_store-menge
                        vzwrk       = ls_store-werks_sup
                        dc_del_date = ls_store-eindt ) TO lt_stores.
      ENDLOOP.
    ENDLOOP.

    " -----------------------------------------------------------------------
    " Llamada al FM RFC_CREATE_ALLOCATION_TABLE_S4
    " En modo Simulación el FM valida sin crear la Tabla de Asignación.
    " -----------------------------------------------------------------------
    DATA lv_alloc_table   TYPE abeln.
    DATA lv_return_code   TYPE sysubrc.
    DATA lt_messages      TYPE rfc_alloc_messages_out_tty.

    CALL FUNCTION 'RFC_CREATE_ALLOCATION_TABLE_S4'
      EXPORTING
        im_simulation           = CONV flag( COND #( WHEN simulation = abap_true THEN 'X' ELSE ' ' ) )
        im_s_rfc_alloc_header_in = ls_header
        iv_prio_vendor          = ls_first-lifnr
      IMPORTING
        ex_alloc_table          = lv_alloc_table
        ex_return_code          = lv_return_code
      TABLES
        im_t_rfc_alloc_items_in  = lt_items
        im_t_rfc_alloc_stores_in = lt_stores
        ex_alloc_messages        = lt_messages.

    " -----------------------------------------------------------------------
    " Construcción del resultado: cabecera y detalle por línea
    " -----------------------------------------------------------------------
    DATA(lv_success) = COND abap_bool( WHEN lv_return_code = 0 THEN abap_true ELSE abap_false ).

    DATA(lv_msg_text) = COND string(
      WHEN lv_success = abap_true AND simulation = abap_false THEN 'Generado correctamente'
      WHEN lv_success = abap_true AND simulation = abap_true  THEN 'Simulación correcta'
      ELSE get_message_text( lt_messages ) ).

    IF lv_success = abap_true.
      c_header-alloc_table  = lv_alloc_table.
      c_header-status       = COND #( WHEN simulation = abap_true THEN 'Simulación' ELSE 'Exitosa' ).
      c_header-success_recs = c_header-total_recs.
      c_header-error_recs   = 0.
    ELSE.
      c_header-status       = 'Error'.
      c_header-success_recs = 0.
      c_header-error_recs   = c_header-total_recs.
    ENDIF.

    LOOP AT i_lines INTO DATA(ls_result_line).
      APPEND VALUE ty_result_detail(
        group_id    = i_group_id
        alloc_table = c_header-alloc_table
        matnr       = ls_result_line-matnr
        werks_rec   = ls_result_line-werks_rec
        menge       = ls_result_line-menge
        meins       = ls_result_line-meins
        result      = COND char6( WHEN lv_success = abap_true THEN 'OK' ELSE 'ERROR' )
        message     = lv_msg_text ) TO c_details.
    ENDLOOP.

  ENDMETHOD.


  METHOD display_results.

    " ALV Cabecera: resumen por Tabla de Asignación generada
    TRY.
        cl_salv_table=>factory(
          IMPORTING
            r_salv_table = DATA(lo_alv_header)
          CHANGING
            t_table      = result_hdr ).

        lo_alv_header->get_columns( )->set_optimize( abap_true ).
        lo_alv_header->get_functions( )->set_all( abap_true ).

        TRY.
            lo_alv_header->get_columns( )->get_column( 'GROUP_ID' )->set_technical( abap_true ).
          CATCH cx_salv_not_found.
        ENDTRY.

        lo_alv_header->get_display_settings( )->set_list_header( 'Resumen por Tabla de Asignación' ).

        lo_alv_header->display( ).

      CATCH cx_root INTO DATA(lx_header_error).
        MESSAGE |No fue posible mostrar el resumen: { lx_header_error->get_text( ) }|
          TYPE 'I' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.

    " ALV Detalle: resultado por cada registro procesado
    TRY.
        cl_salv_table=>factory(
          IMPORTING
            r_salv_table = DATA(lo_alv_detail)
          CHANGING
            t_table      = result_det ).

        lo_alv_detail->get_columns( )->set_optimize( abap_true ).
        lo_alv_detail->get_functions( )->set_all( abap_true ).

        TRY.
            lo_alv_detail->get_columns( )->get_column( 'GROUP_ID' )->set_technical( abap_true ).
          CATCH cx_salv_not_found.
        ENDTRY.

        lo_alv_detail->get_display_settings( )->set_list_header( 'Detalle por Registro' ).

        lo_alv_detail->display( ).

      CATCH cx_root INTO DATA(lx_detail_error).
        MESSAGE |No fue posible mostrar el detalle: { lx_detail_error->get_text( ) }|
          TYPE 'I' DISPLAY LIKE 'E'.
    ENDTRY.

  ENDMETHOD.


  METHOD get_message_text.

    IF it_messages IS INITIAL.
      r_text = 'Error desconocido al generar la Tabla de Asignación'.
      RETURN.
    ENDIF.

    " Intentar leer campo de texto del primer mensaje via field-symbol genérico
    DATA(ls_first_msg) = it_messages[ 1 ].

    ASSIGN COMPONENT 'MESSAGE' OF STRUCTURE ls_first_msg TO FIELD-SYMBOL(<text>).
    IF sy-subrc = 0.
      r_text = <text>.
      RETURN.
    ENDIF.

    ASSIGN COMPONENT 'TEXT' OF STRUCTURE ls_first_msg TO <text>.
    IF sy-subrc = 0.
      r_text = <text>.
      RETURN.
    ENDIF.

    r_text = 'Error al generar la Tabla de Asignación (ver EX_ALLOC_MESSAGES en debug)'.

  ENDMETHOD.

ENDCLASS.
