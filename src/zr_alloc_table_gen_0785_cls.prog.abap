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

    DATA lt_excel    TYPE TABLE OF alsmex_tabline.
    DATA lv_filename TYPE rlgrap-filename.
    lv_filename = file_path.

    CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
      EXPORTING
        filename                = lv_filename
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

      DATA(lv_val) = ls_cell-value.
      CONDENSE lv_val.

      CASE ls_cell-col.
        WHEN 1.
          " LIFNR: agregar ceros a la izquierda (ej. 2000507 → 0002000507)
          CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
            EXPORTING input  = lv_val
            IMPORTING output = <fs_row>-lifnr.
        WHEN 2.
          " Fecha de Entrega: formato DD/MM/AAAA o DD.MM.AAAA
          IF strlen( lv_val ) = 10.
            <fs_row>-eindt = |{ lv_val+6(4) }{ lv_val+3(2) }{ lv_val+0(2) }|.
          ENDIF.
        WHEN 3.
          <fs_row>-ekorg = lv_val.
        WHEN 4.
          <fs_row>-ekgrp = lv_val.
        WHEN 5.
          <fs_row>-werks_sup = lv_val.
        WHEN 6.
          " MATNR: usar el exit propio de material (MATN1), no ALPHA genérico,
          " ya que ALPHA rellena hasta el largo completo del dominio MATNR (40)
          " y produce ceros de más en sistemas con material number extendido.
          CALL FUNCTION 'CONVERSION_EXIT_MATN1_INPUT'
            EXPORTING input        = lv_val
            IMPORTING output       = <fs_row>-matnr
            EXCEPTIONS length_error = 1
                        OTHERS       = 2.
          IF sy-subrc <> 0.
            <fs_row>-matnr = lv_val.
          ENDIF.
        WHEN 7.
          <fs_row>-werks_rec = lv_val.
        WHEN 8.
          " Cantidad: admite coma o punto como separador decimal
          DATA(lv_qty_text) = lv_val.
          REPLACE ALL OCCURRENCES OF ',' IN lv_qty_text WITH '.'.
          TRY.
              <fs_row>-menge = lv_qty_text.
            CATCH cx_root.
              CLEAR <fs_row>-menge.
          ENDTRY.
        WHEN 9.
          " MEINS: convertir de unidad externa a interna (algunas unidades
          " tienen un código interno distinto al texto corto mostrado).
          CALL FUNCTION 'CONVERSION_EXIT_CUNIT_INPUT'
            EXPORTING  input  = lv_val
            IMPORTING  output = <fs_row>-meins
            EXCEPTIONS unit_not_found = 1
                        OTHERS         = 2.
          IF sy-subrc <> 0.
            <fs_row>-meins = lv_val.
          ENDIF.
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
    DATA ls_first    TYPE ty_excel_row.
    DATA lv_prev_key TYPE string.
    DATA lv_curr_key TYPE string.

    DATA(lt_sorted) = excel_data.
    SORT lt_sorted BY lifnr eindt ekorg.

    LOOP AT lt_sorted INTO DATA(ls_row).

      lv_curr_key = ls_row-lifnr && ls_row-eindt && ls_row-ekorg.

      IF lv_curr_key <> lv_prev_key.
        ls_first     = ls_row.
        lv_prev_key  = lv_curr_key.
      ENDIF.

      IF ls_row-ekgrp <> ls_first-ekgrp OR ls_row-werks_sup <> ls_first-werks_sup.
        add_validation_error(
          i_row_num = ls_row-row_num
          i_message = |Grupo de Compras y Centro Suministrador deben ser consistentes |
                    && |para el grupo { ls_row-lifnr } / { ls_row-eindt DATE = USER } / { ls_row-ekorg }| ).
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD process_groups.

    DATA(lt_sorted) = excel_data.
    SORT lt_sorted BY lifnr eindt ekorg.

    " Recolectar claves únicas de agrupación (Proveedor / Fecha Entrega / Org. Compras)
    TYPES: BEGIN OF ty_group_key,
             lifnr TYPE lifnr,
             eindt TYPE dats,
             ekorg TYPE ekorg,
           END OF ty_group_key.

    DATA lt_keys TYPE TABLE OF ty_group_key WITH EMPTY KEY.

    LOOP AT lt_sorted INTO DATA(ls_scan).
      IF NOT line_exists( lt_keys[ lifnr = ls_scan-lifnr
                                   eindt = ls_scan-eindt
                                   ekorg = ls_scan-ekorg ] ).
        APPEND VALUE ty_group_key( lifnr = ls_scan-lifnr
                                   eindt = ls_scan-eindt
                                   ekorg = ls_scan-ekorg ) TO lt_keys.
      ENDIF.
    ENDLOOP.

    " Por cada clave única, filtrar todas las líneas del grupo y generar la tabla
    DATA lv_group_id TYPE i VALUE 0.

    LOOP AT lt_keys INTO DATA(ls_key).

      lv_group_id = lv_group_id + 1.

      DATA(lt_all_lines) = VALUE ty_excel_rows(
        FOR ls IN lt_sorted
        WHERE ( lifnr = ls_key-lifnr
            AND eindt = ls_key-eindt
            AND ekorg = ls_key-ekorg )
        ( ls ) ).

      " Separar líneas válidas de líneas con errores de validación
      DATA lt_valid_lines TYPE ty_excel_rows.
      CLEAR lt_valid_lines.

      LOOP AT lt_all_lines INTO DATA(ls_line).
        DATA(lv_has_error) = abap_false.
        LOOP AT val_errors INTO DATA(ls_verr) WHERE row_num = ls_line-row_num.
          " Registrar fila con error en el ALV de detalle
          APPEND VALUE ty_result_detail(
            group_id  = lv_group_id
            matnr     = ls_line-matnr
            werks_rec = ls_line-werks_rec
            menge     = ls_line-menge
            meins     = ls_line-meins
            result    = 'ERROR'
            message   = ls_verr-message ) TO result_det.
          lv_has_error = abap_true.
        ENDLOOP.
        IF lv_has_error = abap_false.
          APPEND ls_line TO lt_valid_lines.
        ENDIF.
      ENDLOOP.

      DATA(ls_header) = VALUE ty_result_header(
        group_id   = lv_group_id
        lifnr      = ls_key-lifnr
        eindt      = ls_key-eindt
        ekorg      = ls_key-ekorg
        total_recs = lines( lt_all_lines ) ).

      DATA(lt_details) = VALUE ty_result_details( ).

      IF lt_valid_lines IS NOT INITIAL.
        generate_allocation_table(
          EXPORTING
            i_group_id = lv_group_id
            i_lines    = lt_valid_lines
          CHANGING
            c_header   = ls_header
            c_details  = lt_details ).
        APPEND LINES OF lt_details TO result_det.
      ELSE.
        ls_header-status     = 'Error'.
        ls_header-error_recs = ls_header-total_recs.
      ENDIF.

      " Recalcular totales con las filas de error ya registradas
      ls_header-error_recs = ls_header-error_recs +
        lines( lt_all_lines ) - lines( lt_valid_lines ).

      APPEND ls_header TO result_hdr.

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
    DATA lv_alloc_table TYPE abeln.
    DATA lv_return_code TYPE sysubrc.
    DATA lv_msg_text    TYPE string.

    CALL FUNCTION 'RFC_CREATE_ALLOCATION_TABLE_S4'
      EXPORTING
        im_simulation            = CONV flag( COND #( WHEN simulation = abap_true THEN 'X' ELSE ' ' ) )
        im_s_rfc_alloc_header_in = ls_header
        iv_prio_vendor           = ls_first-lifnr
      IMPORTING
        ex_alloc_table           = lv_alloc_table
        ex_return_code           = lv_return_code
      TABLES
        im_t_rfc_alloc_items_in  = lt_items
        im_t_rfc_alloc_stores_in = lt_stores.

    " Capturar el mensaje exacto devuelto por el FM (sy-msg* tras la llamada RFC)
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
      WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO lv_msg_text.

    " -----------------------------------------------------------------------
    " Construcción del resultado: cabecera y detalle por línea
    " -----------------------------------------------------------------------
    DATA(lv_success) = COND abap_bool( WHEN lv_return_code = 0 THEN abap_true ELSE abap_false ).

    IF lv_success = abap_true AND lv_msg_text IS INITIAL.
      lv_msg_text = COND string(
        WHEN simulation = abap_true THEN 'Simulación correcta'
        ELSE 'Generado correctamente' ).
    ENDIF.

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

    " Salida de lista clásica con WRITE/ULINE: no depende de ningún
    " Function Module externo (cuya firma de parámetros puede variar
    " entre sistemas), por lo que no puede fallar por parámetro
    " faltante. Se renderiza igual en SAPGUI clásico y en WebGUI/Fiori.

    " ── ALV Cabecera ──────────────────────────────────────────────
    ULINE.
    WRITE: / 'CABECERA - RESUMEN POR TABLA DE ASIGNACIÓN' COLOR COL_HEADING.
    ULINE.
    WRITE: /1       'Proveedor'        COLOR COL_HEADING,
            12(11)   'Fecha Entrega'    COLOR COL_HEADING,
            24(11)   'Org. Compras'     COLOR COL_HEADING,
            36(18)   'Tabla Asignación' COLOR COL_HEADING,
            55(10)   'Total Reg.'       COLOR COL_HEADING,
            66(9)    'Exitosos'         COLOR COL_HEADING,
            76(9)    'Errores'          COLOR COL_HEADING,
            86       'Estatus'          COLOR COL_HEADING.
    ULINE.

    LOOP AT result_hdr INTO DATA(ls_hdr).
      WRITE: /1       ls_hdr-lifnr,
              12(11)   ls_hdr-eindt,
              24(11)   ls_hdr-ekorg,
              36(18)   ls_hdr-alloc_table,
              55(10)   ls_hdr-total_recs,
              66(9)    ls_hdr-success_recs,
              76(9)    ls_hdr-error_recs,
              86       ls_hdr-status.
    ENDLOOP.
    ULINE.

    SKIP.

    " ── ALV Detalle ───────────────────────────────────────────────
    ULINE.
    WRITE: / 'DETALLE POR MATERIAL' COLOR COL_HEADING.
    ULINE.
    WRITE: /1       'Tabla Asignación' COLOR COL_HEADING,
            20(18)   'Material'         COLOR COL_HEADING,
            39(14)   'Centro Destino'   COLOR COL_HEADING,
            54(10)   'Cantidad'         COLOR COL_HEADING,
            65(4)    'UM'               COLOR COL_HEADING,
            70(10)   'Resultado'        COLOR COL_HEADING,
            81       'Mensaje SAP'      COLOR COL_HEADING.
    ULINE.

    LOOP AT result_det INTO DATA(ls_det).
      WRITE: /1       ls_det-alloc_table,
              20(18)   ls_det-matnr,
              39(14)   ls_det-werks_rec,
              54(10)   ls_det-menge,
              65(4)    ls_det-meins.
      IF ls_det-result = 'OK'.
        WRITE: 70(10) ls_det-result COLOR COL_POSITIVE.
      ELSE.
        WRITE: 70(10) ls_det-result COLOR COL_NEGATIVE.
      ENDIF.
      WRITE: 81 ls_det-message.
    ENDLOOP.
    ULINE.

  ENDMETHOD.



ENDCLASS.
