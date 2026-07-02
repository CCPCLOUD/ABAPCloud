*&---------------------------------------------------------------*
*& Report ZRMM_MASS_ARTICLE_CREATE
*&---------------------------------------------------------------*
*& P157 - Creación Masiva de Artículos (Ticket #26515)
*& Transacción Z sugerida: ZMM_ARTICLE_CREATE
*&
*& Carga un archivo Excel (.xlsx) local con datos de artículos
*& simples/genéricos/variantes de SAP Retail, valida la información
*& obligatoria y dependiente de customizing, genera y procesa el
*& IDoc estándar ARTMAS09 (FM MASTER_IDOC_DISTRIBUTE) y presenta un
*& log de resultados en ALV.
*&
*& Alcance: creación de artículo a nivel mandante/datos básicos
*& (MARA/MAKT/MARC/MARD/MARM/MEAN/MLAN/MBEW/MVKE/WLK2/variantes).
*& Fuera de alcance: extensión posterior a centros/ventas/canales/
*& almacenes vía otras transacciones, clasificación avanzada.
*&
*& NOTA IMPORTANTE PARA EL DESARROLLADOR:
*& Los nombres de segmento y campos usados abajo (E1BPE1MATHEAD,
*& E1BPE1MARART, etc.) corresponden a los segmentos observados en
*& IDocs ARTMAS09 exitosos de referencia. Antes de transportar,
*& confirmar en el sistema destino con WE60/WE30/SE11 que el tipo
*& básico activo expone exactamente estos nombres de segmento y
*& campos; si la versión de Retail usa nombres distintos, ajustar
*& únicamente las TYPES de segmento (sección de tipos), el resto
*& de la lógica funcional no cambia.
*&---------------------------------------------------------------*
REPORT zrmm_mass_article_create MESSAGE-ID zmm_article_create.

TYPE-POOLS: icon.

*&---------------------------------------------------------------*
*& Constantes generales
*&---------------------------------------------------------------*
CONSTANTS:
  gc_mestyp        TYPE edidc-mestyp VALUE 'ARTMAS',
  gc_idoctyp       TYPE edidc-idoctp VALUE 'ARTMAS09',
  gc_default_langu TYPE spras       VALUE 'S',   " Asunción: el Excel no captura idioma; ver 2.1.
  gc_cat_simple    TYPE c LENGTH 2  VALUE '00',
  gc_cat_generico  TYPE c LENGTH 2  VALUE '01',
  gc_cat_variante  TYPE c LENGTH 2  VALUE '02'.

CONSTANTS:
  BEGIN OF gc_status,
    ok      TYPE char1 VALUE 'S',   " Verde  - éxito
    error   TYPE char1 VALUE 'E',   " Rojo   - error
    warning TYPE char1 VALUE 'W',   " Amarillo - advertencia
    simul   TYPE char1 VALUE 'A',   " Azul/Gris - simulado
  END OF gc_status.

*&---------------------------------------------------------------*
*& Tipos: filas crudas de Excel (genéricas)
*&---------------------------------------------------------------*
TYPES:
  ty_int4_table TYPE STANDARD TABLE OF i WITH EMPTY KEY.

TYPES:
  ty_excel_cell TYPE string,
  ty_excel_row  TYPE STANDARD TABLE OF ty_excel_cell WITH EMPTY KEY,
  BEGIN OF ty_excel_sheet_row,
    row_index TYPE i,
    cells     TYPE ty_excel_row,
  END OF ty_excel_sheet_row,
  ty_excel_sheet TYPE STANDARD TABLE OF ty_excel_sheet_row WITH EMPTY KEY.

*&---------------------------------------------------------------*
*& Tipos: filas funcionales (según plantilla ARTMAS09_Carga_Usuario)
*&---------------------------------------------------------------*
TYPES:
  BEGIN OF ty_articulo,
    line_number      TYPE i,
    material         TYPE c LENGTH 40,
    descripcion      TYPE c LENGTH 40,
    matl_type        TYPE c LENGTH 4,
    tipo_carga       TYPE c LENGTH 2,      " 00 / 01 / 02
    material_padre   TYPE c LENGTH 40,
    matl_group       TYPE c LENGTH 9,
    base_uom         TYPE c LENGTH 3,
    char_prof        TYPE c LENGTH 30,
    config_class     TYPE c LENGTH 40,
    valid_from       TYPE c LENGTH 8,
    tax_class        TYPE c LENGTH 1,
    modelo           TYPE c LENGTH 20,
    marca            TYPE c LENGTH 10,
    fashion_attr_1   TYPE c LENGTH 10,
    fashion_attr_2   TYPE c LENGTH 10,
    fashion_attr_3   TYPE c LENGTH 10,
    season_level     TYPE c LENGTH 4,
    is_valid         TYPE abap_bool,
  END OF ty_articulo,
  ty_t_articulo TYPE STANDARD TABLE OF ty_articulo WITH EMPTY KEY.

TYPES:
  BEGIN OF ty_centro,
    material     TYPE c LENGTH 40,
    plant        TYPE c LENGTH 4,
    pur_group    TYPE c LENGTH 3,
    mrp_type     TYPE c LENGTH 2,
    plnd_delry   TYPE c LENGTH 4,
    proc_type    TYPE c LENGTH 1,
    loadinggrp   TYPE c LENGTH 4,
    availcheck   TYPE c LENGTH 2,
    profit_ctr   TYPE c LENGTH 10,
    countryori   TYPE c LENGTH 3,
    distr_prof   TYPE c LENGTH 4,
    neg_stocks   TYPE c LENGTH 1,
  END OF ty_centro,
  ty_t_centro TYPE STANDARD TABLE OF ty_centro WITH EMPTY KEY.

TYPES:
  BEGIN OF ty_almacen,
    material TYPE c LENGTH 40,
    plant    TYPE c LENGTH 4,
    stge_loc TYPE c LENGTH 4,
  END OF ty_almacen,
  ty_t_almacen TYPE STANDARD TABLE OF ty_almacen WITH EMPTY KEY.

TYPES:
  BEGIN OF ty_unidad_ean,
    material  TYPE c LENGTH 40,
    alt_unit  TYPE c LENGTH 3,
    numerator TYPE c LENGTH 9,
    denomintr TYPE c LENGTH 9,
    ean_upc   TYPE c LENGTH 18,
    ean_cat   TYPE c LENGTH 2,
  END OF ty_unidad_ean,
  ty_t_unidad_ean TYPE STANDARD TABLE OF ty_unidad_ean WITH EMPTY KEY.

TYPES:
  BEGIN OF ty_impuesto,
    material    TYPE c LENGTH 40,
    depcountry  TYPE c LENGTH 3,
    tax_type_1  TYPE c LENGTH 4,
    taxclass_1  TYPE c LENGTH 1,
    tax_type_2  TYPE c LENGTH 4,
    taxclass_2  TYPE c LENGTH 1,
  END OF ty_impuesto,
  ty_t_impuesto TYPE STANDARD TABLE OF ty_impuesto WITH EMPTY KEY.

TYPES:
  BEGIN OF ty_valoracion,
    material    TYPE c LENGTH 40,
    val_area    TYPE c LENGTH 4,
    val_class   TYPE c LENGTH 4,
    price_ctrl  TYPE c LENGTH 1,
    moving_pr   TYPE c LENGTH 20,
    std_price   TYPE c LENGTH 20,
    price_unit  TYPE c LENGTH 5,
  END OF ty_valoracion,
  ty_t_valoracion TYPE STANDARD TABLE OF ty_valoracion WITH EMPTY KEY.

TYPES:
  BEGIN OF ty_venta,
    material     TYPE c LENGTH 40,
    sales_org    TYPE c LENGTH 4,
    distr_chan   TYPE c LENGTH 2,
    item_cat     TYPE c LENGTH 4,
    acct_assgt   TYPE c LENGTH 2,
    fecha_inicio TYPE c LENGTH 8,
    fecha_fin    TYPE c LENGTH 8,
    pr_ref_mat   TYPE c LENGTH 40,
  END OF ty_venta,
  ty_t_venta TYPE STANDARD TABLE OF ty_venta WITH EMPTY KEY.

TYPES:
  BEGIN OF ty_caracteristica,
    material   TYPE c LENGTH 40,
    char_name  TYPE c LENGTH 30,
    char_value TYPE c LENGTH 30,
  END OF ty_caracteristica,
  ty_t_caracteristica TYPE STANDARD TABLE OF ty_caracteristica WITH EMPTY KEY.

TYPES:
  BEGIN OF ty_variante,
    material_generico TYPE c LENGTH 40,
    material_variante  TYPE c LENGTH 40,
  END OF ty_variante,
  ty_t_variante TYPE STANDARD TABLE OF ty_variante WITH EMPTY KEY.

TYPES:
  BEGIN OF ty_temporada,
    material   TYPE c LENGTH 40,
    season_yr  TYPE c LENGTH 4,
    season     TYPE c LENGTH 2,
  END OF ty_temporada,
  ty_t_temporada TYPE STANDARD TABLE OF ty_temporada WITH EMPTY KEY.

*&---------------------------------------------------------------*
*& Tipos: log de resultados (grilla ALV)
*&---------------------------------------------------------------*
TYPES:
  BEGIN OF ty_log,
    status        TYPE char1,           " gc_status
    status_icon   TYPE c LENGTH 4,
    line_number   TYPE i,
    material      TYPE c LENGTH 40,
    material_type TYPE c LENGTH 4,
    description   TYPE c LENGTH 40,
    idoc_number   TYPE edi_docnum,
    message_type  TYPE symsgty,
    message       TYPE c LENGTH 220,
    creation_date TYPE sy-datum,
    uname         TYPE syuname,
    idoc_status   TYPE edi_status,
  END OF ty_log,
  ty_t_log TYPE STANDARD TABLE OF ty_log WITH EMPTY KEY.

*&---------------------------------------------------------------*
*& Tipos: segmentos IDoc ARTMAS09 (según mapeo funcional 2.4.4)
*& Deben validarse/ajustarse contra WE60/WE30/SE11 del sistema real.
*&---------------------------------------------------------------*
TYPES:
  BEGIN OF ty_e1bpe1mathead,
    material          TYPE c LENGTH 18,
    material_long     TYPE c LENGTH 40,
    matl_type         TYPE c LENGTH 4,
    matl_group        TYPE c LENGTH 9,
    matl_cat          TYPE c LENGTH 2,
    char_prof         TYPE c LENGTH 30,
    config_class_name TYPE c LENGTH 40,
    basic_view        TYPE c LENGTH 1,
    list_view         TYPE c LENGTH 1,
    sales_view        TYPE c LENGTH 1,
    logdc_view        TYPE c LENGTH 1,
    logst_view        TYPE c LENGTH 1,
    pos_view          TYPE c LENGTH 1,
  END OF ty_e1bpe1mathead,

  BEGIN OF ty_e1bpe1varkey,
    material      TYPE c LENGTH 18,
    material_long TYPE c LENGTH 40,
    variant       TYPE c LENGTH 18,
    variant_long  TYPE c LENGTH 40,
  END OF ty_e1bpe1varkey,

  BEGIN OF ty_e1bpe1ausprt,
    material         TYPE c LENGTH 18,
    material_long    TYPE c LENGTH 40,
    char_name        TYPE c LENGTH 30,
    char_value       TYPE c LENGTH 30,
    char_value_long  TYPE c LENGTH 70,
    char_val_char    TYPE c LENGTH 70,
  END OF ty_e1bpe1ausprt,

  BEGIN OF ty_e1bpe1marart,
    material      TYPE c LENGTH 18,
    material_long TYPE c LENGTH 40,
    base_uom      TYPE c LENGTH 3,
    valid_from    TYPE c LENGTH 8,
    tax_class     TYPE c LENGTH 1,
    conf_matl     TYPE c LENGTH 18,
    pr_ref_mat    TYPE c LENGTH 18,
    item_cat      TYPE c LENGTH 4,
  END OF ty_e1bpe1marart,

  BEGIN OF ty_e1bpe1marart1,
    material_long    TYPE c LENGTH 40,
    conf_matl_long   TYPE c LENGTH 40,
    pr_ref_mat_long  TYPE c LENGTH 40,
    free_char_value  TYPE c LENGTH 20,
    brand_id         TYPE c LENGTH 10,
    fashion_attr_1   TYPE c LENGTH 10,
    fashion_attr_2   TYPE c LENGTH 10,
    fashion_attr_3   TYPE c LENGTH 10,
    season_level     TYPE c LENGTH 4,
  END OF ty_e1bpe1marart1,

  BEGIN OF ty_e1bpe1maktrt,
    material      TYPE c LENGTH 18,
    material_long TYPE c LENGTH 40,
    langu         TYPE spras,
    matl_desc     TYPE c LENGTH 40,
  END OF ty_e1bpe1maktrt,

  BEGIN OF ty_e1bpe1marcrt,
    material      TYPE c LENGTH 18,
    material_long TYPE c LENGTH 40,
    plant         TYPE c LENGTH 4,
    pur_group     TYPE c LENGTH 3,
    mrp_type      TYPE c LENGTH 2,
    plnd_delry    TYPE c LENGTH 4,
    proc_type     TYPE c LENGTH 1,
    loadinggrp    TYPE c LENGTH 4,
    availcheck    TYPE c LENGTH 2,
    profit_ctr    TYPE c LENGTH 10,
    countryori    TYPE c LENGTH 3,
    distr_prof    TYPE c LENGTH 4,
    neg_stocks    TYPE c LENGTH 1,
    sloc_exprc    TYPE c LENGTH 4,
  END OF ty_e1bpe1marcrt,

  BEGIN OF ty_e1bpe1mardrt,
    material      TYPE c LENGTH 18,
    material_long TYPE c LENGTH 40,
    plant         TYPE c LENGTH 4,
    stge_loc      TYPE c LENGTH 4,
  END OF ty_e1bpe1mardrt,

  BEGIN OF ty_e1bpe1marmrt,
    material      TYPE c LENGTH 18,
    material_long TYPE c LENGTH 40,
    alt_unit      TYPE c LENGTH 3,
    numerator     TYPE c LENGTH 9,
    denomintr     TYPE c LENGTH 9,
    ean_upc       TYPE c LENGTH 18,
    ean_cat       TYPE c LENGTH 2,
  END OF ty_e1bpe1marmrt,

  BEGIN OF ty_e1bpe1meanrt,
    material TYPE c LENGTH 18,
    unit     TYPE c LENGTH 3,
    ean_upc  TYPE c LENGTH 18,
    ean_cat  TYPE c LENGTH 2,
  END OF ty_e1bpe1meanrt,

  BEGIN OF ty_e1bpe1mlanrt,
    material    TYPE c LENGTH 18,
    material_long TYPE c LENGTH 40,
    depcountry  TYPE c LENGTH 3,
    tax_type_1  TYPE c LENGTH 4,
    taxclass_1  TYPE c LENGTH 1,
    tax_type_2  TYPE c LENGTH 4,
    taxclass_2  TYPE c LENGTH 1,
  END OF ty_e1bpe1mlanrt,

  BEGIN OF ty_e1bpe1mbewrt,
    material      TYPE c LENGTH 18,
    material_long TYPE c LENGTH 40,
    val_area      TYPE c LENGTH 4,
    val_class     TYPE c LENGTH 4,
    price_ctrl    TYPE c LENGTH 1,
    moving_pr     TYPE c LENGTH 20,
    std_price     TYPE c LENGTH 20,
    price_unit    TYPE c LENGTH 5,
  END OF ty_e1bpe1mbewrt,

  BEGIN OF ty_e1bpe1mvkert,
    material      TYPE c LENGTH 18,
    material_long TYPE c LENGTH 40,
    sales_org     TYPE c LENGTH 4,
    distr_chan    TYPE c LENGTH 2,
    item_cat      TYPE c LENGTH 4,
    acct_assgt    TYPE c LENGTH 2,
    list_st_fr    TYPE c LENGTH 8,
    list_dc_fr    TYPE c LENGTH 8,
    sell_st_fr    TYPE c LENGTH 8,
    sell_dc_fr    TYPE c LENGTH 8,
    list_st_to    TYPE c LENGTH 8,
    list_dc_to    TYPE c LENGTH 8,
    sell_st_to    TYPE c LENGTH 8,
    sell_dc_to    TYPE c LENGTH 8,
    pr_ref_mat    TYPE c LENGTH 18,
    pr_ref_mat_long TYPE c LENGTH 40,
  END OF ty_e1bpe1mvkert,

  BEGIN OF ty_e1bpe1wlk2rt,
    material      TYPE c LENGTH 18,
    material_long TYPE c LENGTH 40,
    sales_org     TYPE c LENGTH 4,
    distr_chan    TYPE c LENGTH 2,
    sell_st_fr    TYPE c LENGTH 8,
    sell_st_to    TYPE c LENGTH 8,
  END OF ty_e1bpe1wlk2rt,

  BEGIN OF ty_e1bpe1maw1rt,
    material      TYPE c LENGTH 18,
    material_long TYPE c LENGTH 40,
    pur_group     TYPE c LENGTH 3,
    countryori    TYPE c LENGTH 3,
    loadinggrp    TYPE c LENGTH 4,
    val_class     TYPE c LENGTH 4,
    list_st_fr    TYPE c LENGTH 8,
    list_dc_fr    TYPE c LENGTH 8,
    sell_st_fr    TYPE c LENGTH 8,
    sell_dc_fr    TYPE c LENGTH 8,
    list_st_to    TYPE c LENGTH 8,
    list_dc_to    TYPE c LENGTH 8,
    sell_st_to    TYPE c LENGTH 8,
    sell_dc_to    TYPE c LENGTH 8,
  END OF ty_e1bpe1maw1rt,

  BEGIN OF ty_e1bpfshseasons,
    material      TYPE c LENGTH 18,
    material_long TYPE c LENGTH 40,
    season_yr     TYPE c LENGTH 4,
    season        TYPE c LENGTH 2,
    season_long   TYPE c LENGTH 2,
  END OF ty_e1bpfshseasons.

*&---------------------------------------------------------------*
*& Pantalla de selección
*&---------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
PARAMETERS:
  p_file TYPE rlgrap-filename OBLIGATORY.                  " Archivo Excel local (.xlsx)
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-002.
PARAMETERS:
  p_sim  TYPE xfeld AS CHECKBOX DEFAULT 'X',                " Modo simulación (2.3/2.4)
  p_stop TYPE xfeld AS CHECKBOX DEFAULT space.               " Detener en error (2.3)
SELECTION-SCREEN END OF BLOCK b2.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.
  PERFORM f4_file_open CHANGING p_file.

START-OF-SELECTION.
  PERFORM main.

*&---------------------------------------------------------------*
*& FORM f4_file_open
*&---------------------------------------------------------------*
FORM f4_file_open CHANGING cv_file TYPE rlgrap-filename.
  DATA: lt_files TYPE filetable,
        lv_rc    TYPE i,
        lv_action TYPE i.

  cl_gui_frontend_services=>file_open_dialog(
    EXPORTING
      window_title            = 'Seleccionar archivo Excel de carga'
      default_extension       = 'xlsx'
      file_filter             = 'Archivos Excel (*.xlsx)|*.xlsx|'
      multiselection          = abap_false
    CHANGING
      file_table               = lt_files
      rc                        = lv_rc
      user_action               = lv_action
    EXCEPTIONS
      file_open_dialog_failed  = 1
      cntl_error                = 2
      error_no_gui              = 3
      not_supported_by_gui      = 4
      OTHERS                    = 5 ).

  IF sy-subrc = 0 AND lv_action = cl_gui_frontend_services=>action_ok.
    READ TABLE lt_files INDEX 1 INTO DATA(ls_file).
    IF sy-subrc = 0.
      cv_file = ls_file-filename.
    ENDIF.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------*
*& Clase utilitaria: normalización de encabezados y helpers X
*&---------------------------------------------------------------*
CLASS lcl_util DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS:
      normalize_header
        IMPORTING iv_header        TYPE string
        RETURNING VALUE(rv_result) TYPE string.
ENDCLASS.

CLASS lcl_util IMPLEMENTATION.
  METHOD normalize_header.
    rv_result = iv_header.
    REPLACE ALL OCCURRENCES OF ` ` IN rv_result WITH ``.
    rv_result = to_upper( rv_result ).
  ENDMETHOD.
ENDCLASS.

*&---------------------------------------------------------------*
*& Clase: lectura de archivo Excel (.xlsx) local
*&---------------------------------------------------------------*
CLASS lcl_excel_reader DEFINITION.
  PUBLIC SECTION.
    METHODS:
      constructor
        IMPORTING iv_file TYPE rlgrap-filename,

      upload
        RAISING cx_fdt_excel_core,

      get_sheet
        IMPORTING iv_sheet_name     TYPE string
        RETURNING VALUE(rt_sheet)   TYPE ty_excel_sheet.

  PRIVATE SECTION.
    DATA: mv_file      TYPE rlgrap-filename,
          mo_xl_doc    TYPE REF TO cl_fdt_xl_spreadsheet,
          mv_xdata     TYPE xstring.

    METHODS:
      read_frontend_file
        RAISING cx_fdt_excel_core.
ENDCLASS.

CLASS lcl_excel_reader IMPLEMENTATION.
  METHOD constructor.
    mv_file = iv_file.
  ENDMETHOD.

  METHOD read_frontend_file.
    DATA: lt_data_tab TYPE STANDARD TABLE OF x255,
          lv_filelength TYPE i.

    cl_gui_frontend_services=>gui_upload(
      EXPORTING
        filename                = mv_file
        filetype                = 'BIN'
      IMPORTING
        filelength              = lv_filelength
      CHANGING
        data_tab                 = lt_data_tab
      EXCEPTIONS
        file_open_error          = 1
        file_read_error           = 2
        no_batch                  = 3
        gui_refuse_filetransfer   = 4
        invalid_type              = 5
        no_authority               = 6
        unknown_error              = 7
        bad_data_format            = 8
        header_not_allowed         = 9
        separator_not_allowed      = 10
        header_too_long            = 11
        unknown_dp_error           = 12
        access_denied              = 13
        dp_out_of_memory           = 14
        disk_full                  = 15
        dp_timeout                 = 16
        not_supported_by_gui       = 17
        error_no_gui                = 18
        OTHERS                      = 19 ).
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE cx_fdt_excel_core.
    ENDIF.

    CALL FUNCTION 'SCMS_BINARY_TO_XSTRING'
      EXPORTING
        input_length = lv_filelength
      IMPORTING
        buffer       = mv_xdata
      TABLES
        binary_tab   = lt_data_tab
      EXCEPTIONS
        failed       = 1
        OTHERS       = 2.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE cx_fdt_excel_core.
    ENDIF.
  ENDMETHOD.

  METHOD upload.
    read_frontend_file( ).
    mo_xl_doc = cl_fdt_xl_spreadsheet=>factory( mv_xdata ).
  ENDMETHOD.

  METHOD get_sheet.
    DATA: lt_itab TYPE REF TO data.
    FIELD-SYMBOLS: <lt_itab> TYPE ANY TABLE,
                    <ls_row>  TYPE any.

    CLEAR rt_sheet.

    TRY.
        CALL METHOD mo_xl_doc->if_fdt_doc_spreadsheet~get_itab_from_sheet
          EXPORTING
            sheet_name        = iv_sheet_name
            i_only_first_row  = abap_false
          IMPORTING
            itab              = lt_itab.
      CATCH cx_fdt_excel_core.
        RETURN.
    ENDTRY.

    ASSIGN lt_itab->* TO <lt_itab>.
    CHECK <lt_itab> IS ASSIGNED.

    DATA(lv_index) = 0.
    LOOP AT <lt_itab> ASSIGNING <ls_row>.
      lv_index = lv_index + 1.
      DATA(ls_sheet_row) = VALUE ty_excel_sheet_row( row_index = lv_index ).

      DATA(lo_struct) = CAST cl_abap_structdescr(
        cl_abap_typedescr=>describe_by_data( <ls_row> ) ).
      LOOP AT lo_struct->components INTO DATA(ls_comp).
        ASSIGN COMPONENT ls_comp-name OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<lv_cell>).
        IF sy-subrc = 0.
          APPEND CONV string( <lv_cell> ) TO ls_sheet_row-cells.
        ENDIF.
      ENDLOOP.

      APPEND ls_sheet_row TO rt_sheet.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

*&---------------------------------------------------------------*
*& Datos globales
*&---------------------------------------------------------------*
DATA:
  gt_articulos      TYPE ty_t_articulo,
  gt_centros        TYPE ty_t_centro,
  gt_almacenes      TYPE ty_t_almacen,
  gt_unidades_ean    TYPE ty_t_unidad_ean,
  gt_impuestos      TYPE ty_t_impuesto,
  gt_valoraciones   TYPE ty_t_valoracion,
  gt_ventas         TYPE ty_t_venta,
  gt_caracteristicas TYPE ty_t_caracteristica,
  gt_variantes      TYPE ty_t_variante,
  gt_temporadas     TYPE ty_t_temporada,
  gt_log            TYPE ty_t_log,
  gv_stop_execution TYPE abap_bool.

*&---------------------------------------------------------------*
*& FORM main - orquesta el flujo completo
*&---------------------------------------------------------------*
FORM main.
  PERFORM load_excel_data.
  CHECK gt_articulos IS NOT INITIAL OR gt_log IS NOT INITIAL.

  PERFORM validate_data.

  IF p_sim = abap_true.
    PERFORM simulate_records.
  ELSE.
    PERFORM process_records.
  ENDIF.

  PERFORM display_log.
ENDFORM.

*&---------------------------------------------------------------*
*& FORM load_excel_data - lee todas las hojas de la plantilla
*&---------------------------------------------------------------*
FORM load_excel_data.
  DATA(lo_reader) = NEW lcl_excel_reader( p_file ).

  TRY.
      lo_reader->upload( ).
    CATCH cx_fdt_excel_core.
      APPEND VALUE ty_log(
        status       = gc_status-error
        message_type = 'E'
        message      = 'No fue posible abrir/leer el archivo Excel seleccionado (formato .xlsx inválido o corrupto).'
        uname        = sy-uname
        creation_date = sy-datum ) TO gt_log.
      RETURN.
  ENDTRY.

  PERFORM parse_articulos       USING lo_reader.
  PERFORM parse_centros         USING lo_reader.
  PERFORM parse_almacenes       USING lo_reader.
  PERFORM parse_unidades_ean    USING lo_reader.
  PERFORM parse_impuestos       USING lo_reader.
  PERFORM parse_valoraciones    USING lo_reader.
  PERFORM parse_ventas          USING lo_reader.
  PERFORM parse_caracteristicas USING lo_reader.
  PERFORM parse_variantes       USING lo_reader.
  PERFORM parse_temporadas      USING lo_reader.
ENDFORM.

*&---------------------------------------------------------------*
*& Helpers genéricos de parsing por hoja
*&---------------------------------------------------------------*
FORM build_header_index
  USING    it_sheet        TYPE ty_excel_sheet
           it_header_names TYPE string_table
  CHANGING ct_index        TYPE ty_int4_table.

  CLEAR ct_index.
  READ TABLE it_sheet INTO DATA(ls_header_row) INDEX 7. " Fila 7 = encabezados (ver plantilla)
  CHECK sy-subrc = 0.

  LOOP AT it_header_names INTO DATA(lv_wanted).
    DATA(lv_wanted_norm) = lcl_util=>normalize_header( lv_wanted ).
    DATA(lv_found) = 0.
    LOOP AT ls_header_row-cells INTO DATA(lv_cell) FROM 1.
      IF lcl_util=>normalize_header( lv_cell ) = lv_wanted_norm.
        lv_found = sy-tabix.
        EXIT.
      ENDIF.
    ENDLOOP.
    APPEND lv_found TO ct_index.
  ENDLOOP.
ENDFORM.

FORM cell_by_index
  USING    is_row  TYPE ty_excel_sheet_row
           iv_idx  TYPE i
  CHANGING cv_value TYPE string.

  CLEAR cv_value.
  CHECK iv_idx > 0.
  READ TABLE is_row-cells INTO cv_value INDEX iv_idx.
  CONDENSE cv_value.
ENDFORM.

*&---------------------------------------------------------------*
*& FORM parse_articulos (hoja 01_ARTICULOS)
*&---------------------------------------------------------------*
FORM parse_articulos USING io_reader TYPE REF TO lcl_excel_reader.
  DATA(lt_sheet) = io_reader->get_sheet( '01_ARTICULOS' ).
  IF lt_sheet IS INITIAL.
    APPEND VALUE ty_log(
      status = gc_status-error message_type = 'E'
      message = 'Hoja 01_ARTICULOS no encontrada o vacía. Es obligatoria.'
      uname = sy-uname creation_date = sy-datum ) TO gt_log.
    RETURN.
  ENDIF.

  DATA(lt_headers) = VALUE string_table(
    ( `Material` ) ( `Descripción corta` ) ( `Tipo de material SAP` )
    ( `Digite: 00 Simple / 01 Genérico / 02 Variante` )
    ( `Material padre genérico` ) ( `Grupo de artículos` ) ( `Unidad base` )
    ( `Perfil características` ) ( `Clase configuración` )
    ( `Fecha inicio validez AAAAMMDD` ) ( `Clase fiscal material` )
    ( `Modelo` ) ( `Marca` ) ( `Atributo fashion 1` ) ( `Atributo fashion 2` )
    ( `Atributo fashion 3` ) ( `Nivel temporada` ) ).
  DATA(lt_idx) = VALUE ty_int4_table( ).
  PERFORM build_header_index USING lt_sheet lt_headers CHANGING lt_idx.

  LOOP AT lt_sheet INTO DATA(ls_row) FROM 8.
    DATA(lv_material) = ``.
    READ TABLE lt_idx INDEX 1 INTO DATA(lv_i1).
    PERFORM cell_by_index USING ls_row lv_i1 CHANGING lv_material.
    CHECK lv_material IS NOT INITIAL.

    DATA(ls_art) = VALUE ty_articulo( line_number = ls_row-row_index ).
    ls_art-material = lv_material.

    READ TABLE lt_idx INDEX 2  INTO DATA(lv_i)  . PERFORM cell_by_index USING ls_row lv_i CHANGING DATA(lv_v). ls_art-descripcion    = lv_v.
    READ TABLE lt_idx INDEX 3  INTO lv_i        . PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.        ls_art-matl_type      = lv_v.
    READ TABLE lt_idx INDEX 4  INTO lv_i        . PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.        ls_art-tipo_carga     = lv_v.
    READ TABLE lt_idx INDEX 5  INTO lv_i        . PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.        ls_art-material_padre = lv_v.
    READ TABLE lt_idx INDEX 6  INTO lv_i        . PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.        ls_art-matl_group     = lv_v.
    READ TABLE lt_idx INDEX 7  INTO lv_i        . PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.        ls_art-base_uom       = lv_v.
    READ TABLE lt_idx INDEX 8  INTO lv_i        . PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.        ls_art-char_prof      = lv_v.
    READ TABLE lt_idx INDEX 9  INTO lv_i        . PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.        ls_art-config_class   = lv_v.
    READ TABLE lt_idx INDEX 10 INTO lv_i        . PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.        ls_art-valid_from     = lv_v.
    READ TABLE lt_idx INDEX 11 INTO lv_i        . PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.        ls_art-tax_class      = lv_v.
    READ TABLE lt_idx INDEX 12 INTO lv_i        . PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.        ls_art-modelo         = lv_v.
    READ TABLE lt_idx INDEX 13 INTO lv_i        . PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.        ls_art-marca          = lv_v.
    READ TABLE lt_idx INDEX 14 INTO lv_i        . PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.        ls_art-fashion_attr_1 = lv_v.
    READ TABLE lt_idx INDEX 15 INTO lv_i        . PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.        ls_art-fashion_attr_2 = lv_v.
    READ TABLE lt_idx INDEX 16 INTO lv_i        . PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.        ls_art-fashion_attr_3 = lv_v.
    READ TABLE lt_idx INDEX 17 INTO lv_i        . PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.        ls_art-season_level   = lv_v.

    APPEND ls_art TO gt_articulos.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------*
*& FORM parse_centros (hoja 02_CENTROS)
*&---------------------------------------------------------------*
FORM parse_centros USING io_reader TYPE REF TO lcl_excel_reader.
  DATA(lt_sheet) = io_reader->get_sheet( '02_CENTROS' ).
  CHECK lt_sheet IS NOT INITIAL.

  DATA(lt_headers) = VALUE string_table(
    ( `Material` ) ( `Centro` ) ( `Grupo compras` ) ( `Tipo MRP` )
    ( `Plazo entrega planificado` ) ( `Tipo aprovisionamiento` )
    ( `Grupo carga` ) ( `Verificación disponibilidad` ) ( `Centro beneficio` )
    ( `País origen` ) ( `Perfil distribución` ) ( `Stock negativo X/vacío` ) ).
  DATA(lt_idx) = VALUE ty_int4_table( ).
  PERFORM build_header_index USING lt_sheet lt_headers CHANGING lt_idx.

  LOOP AT lt_sheet INTO DATA(ls_row) FROM 8.
    READ TABLE lt_idx INDEX 1 INTO DATA(lv_i). PERFORM cell_by_index USING ls_row lv_i CHANGING DATA(lv_material).
    CHECK lv_material IS NOT INITIAL.
    DATA(ls_c) = VALUE ty_centro( material = lv_material ).

    READ TABLE lt_idx INDEX 2  INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING DATA(lv_v). ls_c-plant      = lv_v.
    READ TABLE lt_idx INDEX 3  INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.       ls_c-pur_group  = lv_v.
    READ TABLE lt_idx INDEX 4  INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.       ls_c-mrp_type   = lv_v.
    READ TABLE lt_idx INDEX 5  INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.       ls_c-plnd_delry = lv_v.
    READ TABLE lt_idx INDEX 6  INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.       ls_c-proc_type  = lv_v.
    READ TABLE lt_idx INDEX 7  INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.       ls_c-loadinggrp = lv_v.
    READ TABLE lt_idx INDEX 8  INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.       ls_c-availcheck = lv_v.
    READ TABLE lt_idx INDEX 9  INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.       ls_c-profit_ctr = lv_v.
    READ TABLE lt_idx INDEX 10 INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.       ls_c-countryori = lv_v.
    READ TABLE lt_idx INDEX 11 INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.       ls_c-distr_prof = lv_v.
    READ TABLE lt_idx INDEX 12 INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.       ls_c-neg_stocks = lv_v.

    APPEND ls_c TO gt_centros.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------*
*& FORM parse_almacenes (hoja 03_ALMACENES)
*&---------------------------------------------------------------*
FORM parse_almacenes USING io_reader TYPE REF TO lcl_excel_reader.
  DATA(lt_sheet) = io_reader->get_sheet( '03_ALMACENES' ).
  CHECK lt_sheet IS NOT INITIAL.

  DATA(lt_headers) = VALUE string_table( ( `Material` ) ( `Centro` ) ( `Almacén` ) ).
  DATA(lt_idx) = VALUE ty_int4_table( ).
  PERFORM build_header_index USING lt_sheet lt_headers CHANGING lt_idx.

  LOOP AT lt_sheet INTO DATA(ls_row) FROM 8.
    READ TABLE lt_idx INDEX 1 INTO DATA(lv_i). PERFORM cell_by_index USING ls_row lv_i CHANGING DATA(lv_material).
    CHECK lv_material IS NOT INITIAL.
    DATA(ls_a) = VALUE ty_almacen( material = lv_material ).
    READ TABLE lt_idx INDEX 2 INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING DATA(lv_v). ls_a-plant    = lv_v.
    READ TABLE lt_idx INDEX 3 INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.       ls_a-stge_loc = lv_v.
    APPEND ls_a TO gt_almacenes.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------*
*& FORM parse_unidades_ean (hoja 04_UNIDADES_EAN)
*&---------------------------------------------------------------*
FORM parse_unidades_ean USING io_reader TYPE REF TO lcl_excel_reader.
  DATA(lt_sheet) = io_reader->get_sheet( '04_UNIDADES_EAN' ).
  CHECK lt_sheet IS NOT INITIAL.

  DATA(lt_headers) = VALUE string_table(
    ( `Material` ) ( `Unidad medida` ) ( `Numerador` ) ( `Denominador` )
    ( `EAN/UPC` ) ( `Categoría EAN` ) ).
  DATA(lt_idx) = VALUE ty_int4_table( ).
  PERFORM build_header_index USING lt_sheet lt_headers CHANGING lt_idx.

  LOOP AT lt_sheet INTO DATA(ls_row) FROM 8.
    READ TABLE lt_idx INDEX 1 INTO DATA(lv_i). PERFORM cell_by_index USING ls_row lv_i CHANGING DATA(lv_material).
    CHECK lv_material IS NOT INITIAL.
    DATA(ls_u) = VALUE ty_unidad_ean( material = lv_material ).
    READ TABLE lt_idx INDEX 2 INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING DATA(lv_v). ls_u-alt_unit  = lv_v.
    READ TABLE lt_idx INDEX 3 INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.       ls_u-numerator = lv_v.
    READ TABLE lt_idx INDEX 4 INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.       ls_u-denomintr = lv_v.
    READ TABLE lt_idx INDEX 5 INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.       ls_u-ean_upc   = lv_v.
    READ TABLE lt_idx INDEX 6 INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.       ls_u-ean_cat   = lv_v.
    APPEND ls_u TO gt_unidades_ean.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------*
*& FORM parse_impuestos (hoja 05_IMPUESTOS)
*&---------------------------------------------------------------*
FORM parse_impuestos USING io_reader TYPE REF TO lcl_excel_reader.
  DATA(lt_sheet) = io_reader->get_sheet( '05_IMPUESTOS' ).
  CHECK lt_sheet IS NOT INITIAL.

  DATA(lt_headers) = VALUE string_table(
    ( `Material` ) ( `País` ) ( `Tipo impuesto 1` ) ( `Clasificación impuesto 1` )
    ( `Tipo impuesto 2` ) ( `Clasificación impuesto 2` ) ).
  DATA(lt_idx) = VALUE ty_int4_table( ).
  PERFORM build_header_index USING lt_sheet lt_headers CHANGING lt_idx.

  LOOP AT lt_sheet INTO DATA(ls_row) FROM 8.
    READ TABLE lt_idx INDEX 1 INTO DATA(lv_i). PERFORM cell_by_index USING ls_row lv_i CHANGING DATA(lv_material).
    CHECK lv_material IS NOT INITIAL.
    DATA(ls_t) = VALUE ty_impuesto( material = lv_material ).
    READ TABLE lt_idx INDEX 2 INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING DATA(lv_v). ls_t-depcountry = lv_v.
    READ TABLE lt_idx INDEX 3 INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.       ls_t-tax_type_1 = lv_v.
    READ TABLE lt_idx INDEX 4 INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.       ls_t-taxclass_1 = lv_v.
    READ TABLE lt_idx INDEX 5 INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.       ls_t-tax_type_2 = lv_v.
    READ TABLE lt_idx INDEX 6 INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.       ls_t-taxclass_2 = lv_v.
    APPEND ls_t TO gt_impuestos.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------*
*& FORM parse_valoraciones (hoja 06_VALORACION)
*&---------------------------------------------------------------*
FORM parse_valoraciones USING io_reader TYPE REF TO lcl_excel_reader.
  DATA(lt_sheet) = io_reader->get_sheet( '06_VALORACION' ).
  CHECK lt_sheet IS NOT INITIAL.

  DATA(lt_headers) = VALUE string_table(
    ( `Material` ) ( `Área valoración` ) ( `Clase valoración` ) ( `Control de precio` )
    ( `Precio promedio móvil` ) ( `Precio estándar` ) ( `Unidad de precio` ) ).
  DATA(lt_idx) = VALUE ty_int4_table( ).
  PERFORM build_header_index USING lt_sheet lt_headers CHANGING lt_idx.

  LOOP AT lt_sheet INTO DATA(ls_row) FROM 8.
    READ TABLE lt_idx INDEX 1 INTO DATA(lv_i). PERFORM cell_by_index USING ls_row lv_i CHANGING DATA(lv_material).
    CHECK lv_material IS NOT INITIAL.
    DATA(ls_val) = VALUE ty_valoracion( material = lv_material ).
    READ TABLE lt_idx INDEX 2 INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING DATA(lv_v). ls_val-val_area   = lv_v.
    READ TABLE lt_idx INDEX 3 INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.       ls_val-val_class  = lv_v.
    READ TABLE lt_idx INDEX 4 INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.       ls_val-price_ctrl = lv_v.
    READ TABLE lt_idx INDEX 5 INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.       ls_val-moving_pr  = lv_v.
    READ TABLE lt_idx INDEX 6 INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.       ls_val-std_price  = lv_v.
    READ TABLE lt_idx INDEX 7 INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.       ls_val-price_unit = lv_v.
    APPEND ls_val TO gt_valoraciones.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------*
*& FORM parse_ventas (hoja 07_VENTAS_POS)
*&---------------------------------------------------------------*
FORM parse_ventas USING io_reader TYPE REF TO lcl_excel_reader.
  DATA(lt_sheet) = io_reader->get_sheet( '07_VENTAS_POS' ).
  CHECK lt_sheet IS NOT INITIAL.

  DATA(lt_headers) = VALUE string_table(
    ( `Material` ) ( `Organización ventas` ) ( `Canal distribución` ) ( `Categoría ítem` )
    ( `Grupo imputación` ) ( `Fecha inicio AAAAMMDD` ) ( `Fecha fin AAAAMMDD` )
    ( `Material referencia precio` ) ).
  DATA(lt_idx) = VALUE ty_int4_table( ).
  PERFORM build_header_index USING lt_sheet lt_headers CHANGING lt_idx.

  LOOP AT lt_sheet INTO DATA(ls_row) FROM 8.
    READ TABLE lt_idx INDEX 1 INTO DATA(lv_i). PERFORM cell_by_index USING ls_row lv_i CHANGING DATA(lv_material).
    CHECK lv_material IS NOT INITIAL.
    DATA(ls_ve) = VALUE ty_venta( material = lv_material ).
    READ TABLE lt_idx INDEX 2 INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING DATA(lv_v). ls_ve-sales_org    = lv_v.
    READ TABLE lt_idx INDEX 3 INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.       ls_ve-distr_chan   = lv_v.
    READ TABLE lt_idx INDEX 4 INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.       ls_ve-item_cat     = lv_v.
    READ TABLE lt_idx INDEX 5 INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.       ls_ve-acct_assgt   = lv_v.
    READ TABLE lt_idx INDEX 6 INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.       ls_ve-fecha_inicio = lv_v.
    READ TABLE lt_idx INDEX 7 INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.       ls_ve-fecha_fin    = lv_v.
    READ TABLE lt_idx INDEX 8 INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.       ls_ve-pr_ref_mat   = lv_v.
    APPEND ls_ve TO gt_ventas.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------*
*& FORM parse_caracteristicas (hoja 08_CARACTERISTICAS)
*&---------------------------------------------------------------*
FORM parse_caracteristicas USING io_reader TYPE REF TO lcl_excel_reader.
  DATA(lt_sheet) = io_reader->get_sheet( '08_CARACTERISTICAS' ).
  CHECK lt_sheet IS NOT INITIAL.

  DATA(lt_headers) = VALUE string_table( ( `Material` ) ( `Característica` ) ( `Valor característica` ) ).
  DATA(lt_idx) = VALUE ty_int4_table( ).
  PERFORM build_header_index USING lt_sheet lt_headers CHANGING lt_idx.

  LOOP AT lt_sheet INTO DATA(ls_row) FROM 8.
    READ TABLE lt_idx INDEX 1 INTO DATA(lv_i). PERFORM cell_by_index USING ls_row lv_i CHANGING DATA(lv_material).
    CHECK lv_material IS NOT INITIAL.
    DATA(ls_ch) = VALUE ty_caracteristica( material = lv_material ).
    READ TABLE lt_idx INDEX 2 INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING DATA(lv_v). ls_ch-char_name  = lv_v.
    READ TABLE lt_idx INDEX 3 INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.       ls_ch-char_value = lv_v.
    APPEND ls_ch TO gt_caracteristicas.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------*
*& FORM parse_variantes (hoja 09_VARIANTES)
*&---------------------------------------------------------------*
FORM parse_variantes USING io_reader TYPE REF TO lcl_excel_reader.
  DATA(lt_sheet) = io_reader->get_sheet( '09_VARIANTES' ).
  CHECK lt_sheet IS NOT INITIAL.

  DATA(lt_headers) = VALUE string_table( ( `Material genérico` ) ( `Material variante` ) ).
  DATA(lt_idx) = VALUE ty_int4_table( ).
  PERFORM build_header_index USING lt_sheet lt_headers CHANGING lt_idx.

  LOOP AT lt_sheet INTO DATA(ls_row) FROM 8.
    READ TABLE lt_idx INDEX 1 INTO DATA(lv_i). PERFORM cell_by_index USING ls_row lv_i CHANGING DATA(lv_generico).
    CHECK lv_generico IS NOT INITIAL.
    DATA(ls_va) = VALUE ty_variante( material_generico = lv_generico ).
    READ TABLE lt_idx INDEX 2 INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING DATA(lv_v). ls_va-material_variante = lv_v.
    APPEND ls_va TO gt_variantes.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------*
*& FORM parse_temporadas (hoja 10_TEMPORADAS)
*&---------------------------------------------------------------*
FORM parse_temporadas USING io_reader TYPE REF TO lcl_excel_reader.
  DATA(lt_sheet) = io_reader->get_sheet( '10_TEMPORADAS' ).
  CHECK lt_sheet IS NOT INITIAL.

  DATA(lt_headers) = VALUE string_table( ( `Material` ) ( `Año temporada` ) ( `Temporada` ) ).
  DATA(lt_idx) = VALUE ty_int4_table( ).
  PERFORM build_header_index USING lt_sheet lt_headers CHANGING lt_idx.

  LOOP AT lt_sheet INTO DATA(ls_row) FROM 8.
    READ TABLE lt_idx INDEX 1 INTO DATA(lv_i). PERFORM cell_by_index USING ls_row lv_i CHANGING DATA(lv_material).
    CHECK lv_material IS NOT INITIAL.
    DATA(ls_te) = VALUE ty_temporada( material = lv_material ).
    READ TABLE lt_idx INDEX 2 INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING DATA(lv_v). ls_te-season_yr = lv_v.
    READ TABLE lt_idx INDEX 3 INTO lv_i. PERFORM cell_by_index USING ls_row lv_i CHANGING lv_v.       ls_te-season    = lv_v.
    APPEND ls_te TO gt_temporadas.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------*
*& FORM validate_data - reglas de validación (2.4.6)
*&---------------------------------------------------------------*
FORM validate_data.
  DATA: lt_seen TYPE STANDARD TABLE OF c LENGTH 40 WITH EMPTY KEY.

  LOOP AT gt_articulos ASSIGNING FIELD-SYMBOL(<art>).
    DATA(lv_error) = ``.

    " 1. Campos obligatorios
    IF <art>-matl_type IS INITIAL.
      lv_error = |Tipo de material SAP es obligatorio.|.
    ELSEIF <art>-tipo_carga IS INITIAL OR
           ( <art>-tipo_carga <> gc_cat_simple AND
             <art>-tipo_carga <> gc_cat_generico AND
             <art>-tipo_carga <> gc_cat_variante ).
      lv_error = |Tipo de carga debe ser 00, 01 o 02.|.
    ELSEIF <art>-descripcion IS INITIAL.
      lv_error = |Descripción corta es obligatoria.|.
    ELSEIF <art>-base_uom IS INITIAL.
      lv_error = |Unidad base es obligatoria.|.
    ELSEIF <art>-matl_group IS INITIAL.
      lv_error = |Grupo de artículos es obligatorio.|.
    ELSEIF <art>-tipo_carga = gc_cat_variante AND <art>-material_padre IS INITIAL.
      lv_error = |Material padre genérico es obligatorio para artículos tipo 02 (variante).|.
    ELSEIF ( <art>-tipo_carga = gc_cat_generico OR <art>-tipo_carga = gc_cat_variante ) AND
           ( <art>-char_prof IS INITIAL OR <art>-config_class IS INITIAL ).
      lv_error = |Perfil de características y Clase de configuración son obligatorios para genérico/variante.|.
    ENDIF.

    " 2. Longitud de campos (material máx. 40, según numeración; ajustar a 18 si numeración SAP estándar)
    IF lv_error IS INITIAL AND strlen( <art>-material ) > 40.
      lv_error = |Longitud de Material excede el máximo permitido.|.
    ENDIF.

    " 3. Duplicados dentro del archivo
    IF lv_error IS INITIAL.
      READ TABLE lt_seen TRANSPORTING NO FIELDS WITH KEY table_line = <art>-material.
      IF sy-subrc = 0.
        lv_error = |Material { <art>-material } está duplicado dentro del archivo.|.
      ELSE.
        APPEND <art>-material TO lt_seen.
      ENDIF.
    ENDIF.

    " 4. Material ya existente en SAP (numeración externa)
    IF lv_error IS INITIAL.
      SELECT SINGLE matnr FROM mara INTO @DATA(lv_matnr_db)
        WHERE matnr = @<art>-material.
      IF sy-subrc = 0.
        lv_error = |Material { <art>-material } ya existe en MARA.|.
      ENDIF.
    ENDIF.

    " 5. Unidad de medida válida en customizing (T006)
    IF lv_error IS INITIAL.
      SELECT SINGLE msehi FROM t006 INTO @DATA(lv_uom) WHERE msehi = @<art>-base_uom.
      IF sy-subrc <> 0.
        lv_error = |Unidad base { <art>-base_uom } no es válida en customizing (T006).|.
      ENDIF.
    ENDIF.

    " 6. Tipo de material válido (T134)
    IF lv_error IS INITIAL.
      SELECT SINGLE mtart FROM t134 INTO @DATA(lv_mtart) WHERE mtart = @<art>-matl_type.
      IF sy-subrc <> 0.
        lv_error = |Tipo de material { <art>-matl_type } no existe en customizing (T134).|.
      ENDIF.
    ENDIF.

    " 7. Grupo de artículos válido (T023)
    IF lv_error IS INITIAL.
      SELECT SINGLE matkl FROM t023 INTO @DATA(lv_matkl) WHERE matkl = @<art>-matl_group.
      IF sy-subrc <> 0.
        lv_error = |Grupo de artículos { <art>-matl_group } no existe en customizing (T023).|.
      ENDIF.
    ENDIF.

    " 8. Consistencia de material padre genérico para variantes
    IF lv_error IS INITIAL AND <art>-tipo_carga = gc_cat_variante.
      READ TABLE gt_articulos TRANSPORTING NO FIELDS
        WITH KEY material = <art>-material_padre tipo_carga = gc_cat_generico.
      IF sy-subrc <> 0.
        SELECT SINGLE matnr FROM mara INTO @DATA(lv_padre_db) WHERE matnr = @<art>-material_padre.
        IF sy-subrc <> 0.
          lv_error = |Material padre genérico { <art>-material_padre } no está en el archivo ni existe en SAP.|.
        ENDIF.
      ENDIF.
    ENDIF.

    IF lv_error IS NOT INITIAL.
      <art>-is_valid = abap_false.
      APPEND VALUE ty_log(
        status        = gc_status-error
        line_number   = <art>-line_number
        material      = <art>-material
        material_type = <art>-matl_type
        description   = <art>-descripcion
        message_type  = 'E'
        message       = lv_error
        creation_date = sy-datum
        uname         = sy-uname ) TO gt_log.

      IF p_stop = abap_true.
        gv_stop_execution = abap_true.
        EXIT.
      ENDIF.
    ELSE.
      <art>-is_valid = abap_true.
    ENDIF.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------*
*& FORM simulate_records - modo simulación (no genera IDoc real)
*&---------------------------------------------------------------*
FORM simulate_records.
  LOOP AT gt_articulos INTO DATA(ls_art) WHERE is_valid = abap_true.
    IF gv_stop_execution = abap_true.
      EXIT.
    ENDIF.
    APPEND VALUE ty_log(
      status        = gc_status-simul
      line_number   = ls_art-line_number
      material      = ls_art-material
      material_type = ls_art-matl_type
      description   = ls_art-descripcion
      message_type  = 'I'
      message       = 'Registro validado correctamente (modo simulación, IDoc no generado).'
      creation_date = sy-datum
      uname         = sy-uname ) TO gt_log.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------*
*& FORM process_records - genera y procesa IDoc ARTMAS09 por registro
*&---------------------------------------------------------------*
FORM process_records.
  LOOP AT gt_articulos INTO DATA(ls_art) WHERE is_valid = abap_true.
    IF gv_stop_execution = abap_true.
      EXIT.
    ENDIF.
    PERFORM build_and_send_idoc USING ls_art.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------*
*& FORM build_and_send_idoc - construye segmentos ARTMAS09 y
*&                            los envía vía MASTER_IDOC_DISTRIBUTE
*&---------------------------------------------------------------*
FORM build_and_send_idoc USING is_art TYPE ty_articulo.
  DATA: lt_edidd        TYPE STANDARD TABLE OF edidd,
        ls_edidc        TYPE edidc,
        lt_edidc_result TYPE STANDARD TABLE OF edidc,
        lv_header_matnr TYPE c LENGTH 40,
        lv_data_matnr   TYPE c LENGTH 40.

  " Determinación de material de cabecera (MATHEAD) y material de datos
  " según regla 2.4.4: tipo 02 -> cabecera = genérico, datos = variante.
  IF is_art-tipo_carga = gc_cat_variante.
    lv_header_matnr = is_art-material_padre.
    lv_data_matnr   = is_art-material.
  ELSE.
    lv_header_matnr = is_art-material.
    lv_data_matnr   = is_art-material.
  ENDIF.

  PERFORM fill_segments
    USING is_art lv_header_matnr lv_data_matnr
    CHANGING lt_edidd.

  " Control record EDIDC
  CLEAR ls_edidc.
  ls_edidc-mestyp = gc_mestyp.
  ls_edidc-idoctp = gc_idoctyp.
  ls_edidc-direct = '1'.   " Outbound desde la Z / Inbound hacia procesamiento estándar

  CALL FUNCTION 'MASTER_IDOC_DISTRIBUTE'
    EXPORTING
      master_idoc_control            = ls_edidc
    TABLES
      communication_idoc_control     = lt_edidc_result
      master_idoc_data                = lt_edidd
    EXCEPTIONS
      error_in_idoc_control            = 1
      error_writing_idoc_status         = 2
      error_in_idoc_data                = 3
      sending_logical_system_unknown    = 4
      OTHERS                            = 5.

  IF sy-subrc <> 0.
    APPEND VALUE ty_log(
      status        = gc_status-error
      line_number   = is_art-line_number
      material      = is_art-material
      material_type = is_art-matl_type
      description   = is_art-descripcion
      message_type  = 'E'
      message       = |Error al distribuir el IDoc ({ sy-subrc }): { sy-msgv1 }{ sy-msgv2 }|
      creation_date = sy-datum
      uname         = sy-uname ) TO gt_log.

    IF p_stop = abap_true.
      gv_stop_execution = abap_true.
    ENDIF.
    RETURN.
  ENDIF.

  READ TABLE lt_edidc_result INTO DATA(ls_result) INDEX 1.
  IF sy-subrc = 0.
    DATA(lv_status_log) = COND char1(
      WHEN ls_result-status = '51' OR ls_result-status = '56' OR ls_result-status = '02' THEN gc_status-error
      WHEN ls_result-status = '64' OR ls_result-status = '30' THEN gc_status-warning
      ELSE gc_status-ok ).

    APPEND VALUE ty_log(
      status        = lv_status_log
      line_number   = is_art-line_number
      material      = is_art-material
      material_type = is_art-matl_type
      description   = is_art-descripcion
      idoc_number   = ls_result-docnum
      message_type  = COND symsgty( WHEN lv_status_log = gc_status-error THEN 'E'
                                     WHEN lv_status_log = gc_status-warning THEN 'W'
                                     ELSE 'S' )
      message       = |IDoc { ls_result-docnum } generado. Estatus { ls_result-status }.|
      creation_date = sy-datum
      uname         = sy-uname
      idoc_status   = ls_result-status ) TO gt_log.

    IF lv_status_log = gc_status-error AND p_stop = abap_true.
      gv_stop_execution = abap_true.
    ENDIF.
  ELSE.
    APPEND VALUE ty_log(
      status        = gc_status-warning
      line_number   = is_art-line_number
      material      = is_art-material
      material_type = is_art-matl_type
      description   = is_art-descripcion
      message_type  = 'W'
      message       = 'IDoc enviado; sin confirmación inmediata de número de documento.'
      creation_date = sy-datum
      uname         = sy-uname ) TO gt_log.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------*
*& FORM fill_segments - construye la tabla EDIDD (segmentos ARTMAS09)
*&---------------------------------------------------------------*
FORM fill_segments
  USING    is_art          TYPE ty_articulo
           iv_header_matnr TYPE c
           iv_data_matnr   TYPE c
  CHANGING ct_edidd        TYPE STANDARD TABLE.

  DATA: ls_mathead   TYPE ty_e1bpe1mathead,
        ls_varkey    TYPE ty_e1bpe1varkey,
        ls_marart    TYPE ty_e1bpe1marart,
        ls_marart1   TYPE ty_e1bpe1marart1,
        ls_maktrt    TYPE ty_e1bpe1maktrt,
        ls_maw1rt    TYPE ty_e1bpe1maw1rt,
        ls_ausprt    TYPE ty_e1bpe1ausprt,
        ls_marcrt    TYPE ty_e1bpe1marcrt,
        ls_mardrt    TYPE ty_e1bpe1mardrt,
        ls_marmrt    TYPE ty_e1bpe1marmrt,
        ls_meanrt    TYPE ty_e1bpe1meanrt,
        ls_mlanrt    TYPE ty_e1bpe1mlanrt,
        ls_mbewrt    TYPE ty_e1bpe1mbewrt,
        ls_mvkert    TYPE ty_e1bpe1mvkert,
        ls_wlk2rt    TYPE ty_e1bpe1wlk2rt,
        ls_fshseason TYPE ty_e1bpfshseasons.

  " ---------- E1BPE1MATHEAD ----------
  CLEAR ls_mathead.
  ls_mathead-material      = iv_header_matnr.
  ls_mathead-material_long = iv_header_matnr.
  ls_mathead-matl_type     = is_art-matl_type.
  ls_mathead-matl_group    = is_art-matl_group.
  ls_mathead-basic_view    = 'X'.
  ls_mathead-list_view     = 'X'.
  ls_mathead-sales_view    = 'X'.
  ls_mathead-logdc_view    = 'X'.
  ls_mathead-logst_view    = 'X'.
  ls_mathead-pos_view      = 'X'.

  IF is_art-tipo_carga = gc_cat_simple.
    ls_mathead-matl_cat = gc_cat_simple.
  ELSE.
    " 01 Genérico y 02 Variante generan MATHEAD con MATL_CAT=01 (2.4.4)
    ls_mathead-matl_cat       = gc_cat_generico.
    ls_mathead-char_prof      = is_art-char_prof.
    ls_mathead-config_class_name = is_art-config_class.
  ENDIF.
  PERFORM append_segment USING 'E1BPE1MATHEAD' ls_mathead CHANGING ct_edidd.

  " ---------- E1BPE1VARKEY (genérico/variante) ----------
  IF is_art-tipo_carga = gc_cat_variante.
    CLEAR ls_varkey.
    ls_varkey-material      = iv_header_matnr.
    ls_varkey-material_long = iv_header_matnr.
    ls_varkey-variant       = iv_data_matnr.
    ls_varkey-variant_long  = iv_data_matnr.
    PERFORM append_segment USING 'E1BPE1VARKEY' ls_varkey CHANGING ct_edidd.
  ELSEIF is_art-tipo_carga = gc_cat_generico.
    LOOP AT gt_variantes INTO DATA(ls_var) WHERE material_generico = iv_header_matnr.
      CLEAR ls_varkey.
      ls_varkey-material      = iv_header_matnr.
      ls_varkey-material_long = iv_header_matnr.
      ls_varkey-variant       = ls_var-material_variante.
      ls_varkey-variant_long  = ls_var-material_variante.
      PERFORM append_segment USING 'E1BPE1VARKEY' ls_varkey CHANGING ct_edidd.
    ENDLOOP.
  ENDIF.

  " ---------- E1BPE1AUSPRT (características genérico/variante) ----------
  IF is_art-tipo_carga <> gc_cat_simple.
    LOOP AT gt_caracteristicas INTO DATA(ls_char) WHERE material = iv_data_matnr.
      CLEAR ls_ausprt.
      ls_ausprt-material        = iv_data_matnr.
      ls_ausprt-material_long   = iv_data_matnr.
      ls_ausprt-char_name       = ls_char-char_name.
      ls_ausprt-char_value      = ls_char-char_value.
      ls_ausprt-char_value_long = ls_char-char_value.
      ls_ausprt-char_val_char   = ls_char-char_value.
      PERFORM append_segment USING 'E1BPE1AUSPRT' ls_ausprt CHANGING ct_edidd.
    ENDLOOP.
  ENDIF.

  " ---------- Datos de venta (para PR_REF_MAT / ITEM_CAT) ----------
  READ TABLE gt_ventas INTO DATA(ls_venta_ref) WITH KEY material = iv_data_matnr.

  " ---------- E1BPE1MARART / E1BPE1MARART1 ----------
  CLEAR ls_marart.
  ls_marart-material      = iv_data_matnr.
  ls_marart-material_long = iv_data_matnr.
  ls_marart-base_uom      = is_art-base_uom.
  ls_marart-valid_from    = is_art-valid_from.
  ls_marart-tax_class     = is_art-tax_class.
  IF is_art-tipo_carga = gc_cat_variante.
    ls_marart-conf_matl  = iv_header_matnr.
    ls_marart-pr_ref_mat = COND #( WHEN ls_venta_ref-pr_ref_mat IS NOT INITIAL
                                    THEN ls_venta_ref-pr_ref_mat ELSE iv_header_matnr ).
  ENDIF.
  ls_marart-item_cat = ls_venta_ref-item_cat.
  PERFORM append_segment USING 'E1BPE1MARART' ls_marart CHANGING ct_edidd.

  CLEAR ls_marart1.
  ls_marart1-material_long   = iv_data_matnr.
  IF is_art-tipo_carga = gc_cat_variante.
    ls_marart1-conf_matl_long  = iv_header_matnr.
    ls_marart1-pr_ref_mat_long = ls_marart-pr_ref_mat.
  ENDIF.
  ls_marart1-brand_id        = is_art-marca.
  ls_marart1-free_char_value = is_art-modelo.
  ls_marart1-fashion_attr_1  = is_art-fashion_attr_1.
  ls_marart1-fashion_attr_2  = is_art-fashion_attr_2.
  ls_marart1-fashion_attr_3  = is_art-fashion_attr_3.
  ls_marart1-season_level    = is_art-season_level.
  PERFORM append_segment USING 'E1BPE1MARART1' ls_marart1 CHANGING ct_edidd.

  " ---------- E1BPE1MAKTRT ----------
  CLEAR ls_maktrt.
  ls_maktrt-material      = iv_data_matnr.
  ls_maktrt-material_long = iv_data_matnr.
  ls_maktrt-langu         = gc_default_langu.
  ls_maktrt-matl_desc     = is_art-descripcion.
  PERFORM append_segment USING 'E1BPE1MAKTRT' ls_maktrt CHANGING ct_edidd.

  " ---------- E1BPE1MAW1RT (derivado, primer centro/valoración/venta) ----------
  READ TABLE gt_centros INTO DATA(ls_centro_ref) WITH KEY material = iv_data_matnr.
  READ TABLE gt_valoraciones INTO DATA(ls_val_ref) WITH KEY material = iv_data_matnr.
  IF sy-subrc = 0 OR ls_centro_ref IS NOT INITIAL OR ls_venta_ref IS NOT INITIAL.
    CLEAR ls_maw1rt.
    ls_maw1rt-material      = iv_data_matnr.
    ls_maw1rt-material_long = iv_data_matnr.
    ls_maw1rt-pur_group     = ls_centro_ref-pur_group.
    ls_maw1rt-countryori    = ls_centro_ref-countryori.
    ls_maw1rt-loadinggrp    = ls_centro_ref-loadinggrp.
    ls_maw1rt-val_class     = ls_val_ref-val_class.
    ls_maw1rt-list_st_fr    = ls_venta_ref-fecha_inicio.
    ls_maw1rt-list_dc_fr    = ls_venta_ref-fecha_inicio.
    ls_maw1rt-sell_st_fr    = ls_venta_ref-fecha_inicio.
    ls_maw1rt-sell_dc_fr    = ls_venta_ref-fecha_inicio.
    ls_maw1rt-list_st_to    = ls_venta_ref-fecha_fin.
    ls_maw1rt-list_dc_to    = ls_venta_ref-fecha_fin.
    ls_maw1rt-sell_st_to    = ls_venta_ref-fecha_fin.
    ls_maw1rt-sell_dc_to    = ls_venta_ref-fecha_fin.
    PERFORM append_segment USING 'E1BPE1MAW1RT' ls_maw1rt CHANGING ct_edidd.
  ENDIF.

  " ---------- E1BPE1MARCRT (una instancia por centro) ----------
  LOOP AT gt_centros INTO DATA(ls_centro) WHERE material = iv_data_matnr.
    CLEAR ls_marcrt.
    ls_marcrt-material      = iv_data_matnr.
    ls_marcrt-material_long = iv_data_matnr.
    ls_marcrt-plant         = ls_centro-plant.
    ls_marcrt-pur_group     = ls_centro-pur_group.
    ls_marcrt-mrp_type      = ls_centro-mrp_type.
    ls_marcrt-plnd_delry    = ls_centro-plnd_delry.
    ls_marcrt-proc_type     = ls_centro-proc_type.
    ls_marcrt-loadinggrp    = ls_centro-loadinggrp.
    ls_marcrt-availcheck    = ls_centro-availcheck.
    ls_marcrt-profit_ctr    = ls_centro-profit_ctr.
    ls_marcrt-countryori    = ls_centro-countryori.
    ls_marcrt-distr_prof    = ls_centro-distr_prof.
    ls_marcrt-neg_stocks    = ls_centro-neg_stocks.

    READ TABLE gt_almacenes INTO DATA(ls_alm_ref)
      WITH KEY material = iv_data_matnr plant = ls_centro-plant.
    IF sy-subrc = 0.
      ls_marcrt-sloc_exprc = ls_alm_ref-stge_loc.
    ENDIF.

    PERFORM append_segment USING 'E1BPE1MARCRT' ls_marcrt CHANGING ct_edidd.
  ENDLOOP.

  " ---------- E1BPE1MARDRT (una instancia por centro + almacén) ----------
  LOOP AT gt_almacenes INTO DATA(ls_almacen) WHERE material = iv_data_matnr.
    CLEAR ls_mardrt.
    ls_mardrt-material      = iv_data_matnr.
    ls_mardrt-material_long = iv_data_matnr.
    ls_mardrt-plant         = ls_almacen-plant.
    ls_mardrt-stge_loc      = ls_almacen-stge_loc.
    PERFORM append_segment USING 'E1BPE1MARDRT' ls_mardrt CHANGING ct_edidd.
  ENDLOOP.

  " ---------- E1BPE1MARMRT / E1BPE1MEANRT (unidades y EAN) ----------
  LOOP AT gt_unidades_ean INTO DATA(ls_uni) WHERE material = iv_data_matnr.
    CLEAR ls_marmrt.
    ls_marmrt-material      = iv_data_matnr.
    ls_marmrt-material_long = iv_data_matnr.
    ls_marmrt-alt_unit       = ls_uni-alt_unit.
    ls_marmrt-numerator      = ls_uni-numerator.
    ls_marmrt-denomintr      = ls_uni-denomintr.
    ls_marmrt-ean_upc        = ls_uni-ean_upc.
    ls_marmrt-ean_cat        = ls_uni-ean_cat.
    PERFORM append_segment USING 'E1BPE1MARMRT' ls_marmrt CHANGING ct_edidd.

    IF ls_uni-ean_upc IS NOT INITIAL.
      CLEAR ls_meanrt.
      ls_meanrt-material = iv_data_matnr.
      ls_meanrt-unit     = ls_uni-alt_unit.
      ls_meanrt-ean_upc  = ls_uni-ean_upc.
      ls_meanrt-ean_cat  = ls_uni-ean_cat.
      PERFORM append_segment USING 'E1BPE1MEANRT' ls_meanrt CHANGING ct_edidd.
    ENDIF.
  ENDLOOP.

  " ---------- E1BPE1MLANRT (impuestos) ----------
  LOOP AT gt_impuestos INTO DATA(ls_imp) WHERE material = iv_data_matnr.
    CLEAR ls_mlanrt.
    ls_mlanrt-material      = iv_data_matnr.
    ls_mlanrt-material_long = iv_data_matnr.
    ls_mlanrt-depcountry    = ls_imp-depcountry.
    ls_mlanrt-tax_type_1    = ls_imp-tax_type_1.
    ls_mlanrt-taxclass_1    = ls_imp-taxclass_1.
    ls_mlanrt-tax_type_2    = ls_imp-tax_type_2.
    ls_mlanrt-taxclass_2    = ls_imp-taxclass_2.
    PERFORM append_segment USING 'E1BPE1MLANRT' ls_mlanrt CHANGING ct_edidd.
  ENDLOOP.

  " ---------- E1BPE1MBEWRT (valoración) ----------
  LOOP AT gt_valoraciones INTO DATA(ls_val) WHERE material = iv_data_matnr.
    CLEAR ls_mbewrt.
    ls_mbewrt-material      = iv_data_matnr.
    ls_mbewrt-material_long = iv_data_matnr.
    ls_mbewrt-val_area      = ls_val-val_area.
    ls_mbewrt-val_class     = ls_val-val_class.
    ls_mbewrt-price_ctrl    = ls_val-price_ctrl.
    ls_mbewrt-moving_pr     = ls_val-moving_pr.
    ls_mbewrt-std_price     = ls_val-std_price.
    ls_mbewrt-price_unit    = ls_val-price_unit.
    PERFORM append_segment USING 'E1BPE1MBEWRT' ls_mbewrt CHANGING ct_edidd.
  ENDLOOP.

  " ---------- E1BPE1MVKERT / E1BPE1WLK2RT (ventas / POS) ----------
  LOOP AT gt_ventas INTO DATA(ls_ven) WHERE material = iv_data_matnr.
    CLEAR ls_mvkert.
    ls_mvkert-material        = iv_data_matnr.
    ls_mvkert-material_long   = iv_data_matnr.
    ls_mvkert-sales_org       = ls_ven-sales_org.
    ls_mvkert-distr_chan      = ls_ven-distr_chan.
    ls_mvkert-item_cat        = ls_ven-item_cat.
    ls_mvkert-acct_assgt      = ls_ven-acct_assgt.
    ls_mvkert-list_st_fr      = ls_ven-fecha_inicio.
    ls_mvkert-list_dc_fr      = ls_ven-fecha_inicio.
    ls_mvkert-sell_st_fr      = ls_ven-fecha_inicio.
    ls_mvkert-sell_dc_fr      = ls_ven-fecha_inicio.
    ls_mvkert-list_st_to      = ls_ven-fecha_fin.
    ls_mvkert-list_dc_to      = ls_ven-fecha_fin.
    ls_mvkert-sell_st_to      = ls_ven-fecha_fin.
    ls_mvkert-sell_dc_to      = ls_ven-fecha_fin.
    IF is_art-tipo_carga = gc_cat_variante.
      ls_mvkert-pr_ref_mat      = COND #( WHEN ls_ven-pr_ref_mat IS NOT INITIAL
                                           THEN ls_ven-pr_ref_mat ELSE iv_header_matnr ).
      ls_mvkert-pr_ref_mat_long = ls_mvkert-pr_ref_mat.
    ENDIF.
    PERFORM append_segment USING 'E1BPE1MVKERT' ls_mvkert CHANGING ct_edidd.

    CLEAR ls_wlk2rt.
    ls_wlk2rt-material      = iv_data_matnr.
    ls_wlk2rt-material_long = iv_data_matnr.
    ls_wlk2rt-sales_org     = ls_ven-sales_org.
    ls_wlk2rt-distr_chan    = ls_ven-distr_chan.
    ls_wlk2rt-sell_st_fr    = ls_ven-fecha_inicio.
    ls_wlk2rt-sell_st_to    = ls_ven-fecha_fin.
    PERFORM append_segment USING 'E1BPE1WLK2RT' ls_wlk2rt CHANGING ct_edidd.
  ENDLOOP.

  " ---------- E1BPFSHSEASONS (temporadas) ----------
  LOOP AT gt_temporadas INTO DATA(ls_temp) WHERE material = iv_data_matnr.
    CLEAR ls_fshseason.
    ls_fshseason-material      = iv_data_matnr.
    ls_fshseason-material_long = iv_data_matnr.
    ls_fshseason-season_yr     = ls_temp-season_yr.
    ls_fshseason-season        = ls_temp-season.
    ls_fshseason-season_long   = ls_temp-season.
    PERFORM append_segment USING 'E1BPFSHSEASONS' ls_fshseason CHANGING ct_edidd.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------*
*& FORM append_segment - agrega segmento RT + su segmento X asociado
*&                       (checkbox) a la tabla EDIDD del IDoc.
*&---------------------------------------------------------------*
FORM append_segment
  USING    iv_segnam TYPE edidd-segnam
           is_data    TYPE any
  CHANGING ct_edidd  TYPE STANDARD TABLE.

  DATA: ls_edidd TYPE edidd.

  CLEAR ls_edidd.
  ls_edidd-segnam = iv_segnam.
  ls_edidd-sdata  = is_data.
  APPEND ls_edidd TO ct_edidd.

  " Segmento de casilla de verificación (X) - marca los campos poblados
  " para indicar a SAP qué atributos crear (detalle técnico, 2.4.5).
  DATA ls_data_x LIKE is_data.
  ls_data_x = is_data.
  PERFORM fill_x_segment CHANGING ls_data_x.

  CLEAR ls_edidd.
  ls_edidd-segnam = |{ iv_segnam }X|.
  ls_edidd-sdata  = ls_data_x.
  APPEND ls_edidd TO ct_edidd.
ENDFORM.

*&---------------------------------------------------------------*
*& FORM fill_x_segment - convierte cada campo no llave con valor
*&                       poblado en 'X' (patrón estándar de
*&                       segmentos checkbox de BAPI/IDoc).
*&                       Campos llave (MATERIAL, PLANT, etc.) se
*&                       conservan con su valor real.
*&---------------------------------------------------------------*
FORM fill_x_segment CHANGING cs_data TYPE any.
  DATA(lo_struct) = CAST cl_abap_structdescr(
    cl_abap_typedescr=>describe_by_data( cs_data ) ).

  DATA(lt_key_fields) = VALUE string_table(
    ( `MATERIAL` ) ( `MATERIAL_LONG` ) ( `VARIANT` ) ( `VARIANT_LONG` )
    ( `PLANT` ) ( `STGE_LOC` ) ( `ALT_UNIT` ) ( `UNIT` ) ( `DEPCOUNTRY` )
    ( `VAL_AREA` ) ( `SALES_ORG` ) ( `DISTR_CHAN` ) ( `SEASON_YR` )
    ( `SEASON` ) ( `SEASON_LONG` ) ( `CHAR_NAME` ) ).

  LOOP AT lo_struct->components INTO DATA(ls_comp).
    ASSIGN COMPONENT ls_comp-name OF STRUCTURE cs_data TO FIELD-SYMBOL(<lv_field>).
    CHECK sy-subrc = 0.

    READ TABLE lt_key_fields TRANSPORTING NO FIELDS WITH KEY table_line = ls_comp-name.
    IF sy-subrc = 0.
      CONTINUE. " Los campos llave conservan su valor real.
    ENDIF.

    IF <lv_field> IS NOT INITIAL.
      <lv_field> = 'X'.
    ENDIF.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------*
*& FORM display_log - grilla ALV de resultados (2.4.8)
*&---------------------------------------------------------------*
FORM display_log.
  DATA: lo_salv      TYPE REF TO cl_salv_table,
        lo_functions TYPE REF TO cl_salv_functions_list,
        lo_columns   TYPE REF TO cl_salv_columns_table,
        lo_column    TYPE REF TO cl_salv_column_table,
        lo_display   TYPE REF TO cl_salv_display_settings.

  IF gt_log IS INITIAL.
    MESSAGE 'No se generaron registros de log (archivo vacío o sin filas útiles).' TYPE 'I'.
    RETURN.
  ENDIF.

  PERFORM set_status_icons.

  TRY.
      cl_salv_table=>factory(
        IMPORTING r_salv_table = lo_salv
        CHANGING  t_table       = gt_log ).
    CATCH cx_salv_msg.
      WRITE: / 'Error al inicializar ALV.'.
      RETURN.
  ENDTRY.

  lo_functions = lo_salv->get_functions( ).
  lo_functions->set_all( abap_true ).

  lo_display = lo_salv->get_display_settings( ).
  lo_display->set_striped_pattern( abap_true ).

  lo_salv->get_sorts( )->add_sort( 'LINE_NUMBER' ).

  TRY.
      lo_columns = lo_salv->get_columns( ).
      lo_columns->set_optimize( abap_true ).

      lo_column ?= lo_columns->get_column( 'STATUS' ).
      lo_column->set_technical( abap_true ).

      lo_column ?= lo_columns->get_column( 'STATUS_ICON' ).
      lo_column->set_short_text( 'Estat.' ).
      lo_column->set_medium_text( 'Estatus' ).
      lo_column->set_icon( abap_true ).

      lo_column ?= lo_columns->get_column( 'LINE_NUMBER' ).
      lo_column->set_medium_text( 'Línea Excel' ).

      lo_column ?= lo_columns->get_column( 'MATERIAL' ).
      lo_column->set_medium_text( 'Material' ).

      lo_column ?= lo_columns->get_column( 'IDOC_NUMBER' ).
      lo_column->set_medium_text( 'Nº IDoc' ).

      lo_column ?= lo_columns->get_column( 'MESSAGE' ).
      lo_column->set_long_text( 'Mensaje' ).
      lo_column->set_output_length( 100 ).
    CATCH cx_salv_not_found.
  ENDTRY.

  PERFORM show_totals.

  lo_salv->display( ).
ENDFORM.

*&---------------------------------------------------------------*
*& FORM set_status_icons - asigna el ícono de semáforo por estatus
*&                         (2.4.8: Verde=éxito, Rojo=error,
*&                          Amarillo=advertencia, Azul=simulado)
*&---------------------------------------------------------------*
FORM set_status_icons.
  LOOP AT gt_log ASSIGNING FIELD-SYMBOL(<log>).
    CASE <log>-status.
      WHEN gc_status-ok.
        <log>-status_icon = icon_green_light.
      WHEN gc_status-error.
        <log>-status_icon = icon_red_light.
      WHEN gc_status-warning.
        <log>-status_icon = icon_yellow_light.
      WHEN gc_status-simul.
        <log>-status_icon = icon_system_simulate.
    ENDCASE.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------*
*& FORM show_totals - indicadores de totales (2.4.9 / ejemplo ALV)
*&---------------------------------------------------------------*
FORM show_totals.
  DATA(lv_procesados) = lines( gt_log ).
  DATA(lv_exitos)      = REDUCE i( INIT x = 0 FOR ls IN gt_log
                                    WHERE ( status = gc_status-ok ) NEXT x = x + 1 ).
  DATA(lv_errores)     = REDUCE i( INIT x = 0 FOR ls IN gt_log
                                    WHERE ( status = gc_status-error ) NEXT x = x + 1 ).
  DATA(lv_advert)      = REDUCE i( INIT x = 0 FOR ls IN gt_log
                                    WHERE ( status = gc_status-warning ) NEXT x = x + 1 ).

  MESSAGE i398(00) WITH |Totales: Procesados { lv_procesados } | &&
                        |Éxitos { lv_exitos } | &&
                        |Errores { lv_errores } | &&
                        |Advertencias { lv_advert }|.
ENDFORM.
