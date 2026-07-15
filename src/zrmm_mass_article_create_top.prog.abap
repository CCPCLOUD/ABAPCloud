*&---------------------------------------------------------------*
*& Include ZRMM_MASS_ARTICLE_CREATE_TOP
*&---------------------------------------------------------------*
*& Declaraciones globales: tipos, constantes, pantalla de
*& selección, definición de clases locales de soporte (la
*& implementación va en el include F01: un include TOP solo puede
*& contener declaraciones, no CLASS...IMPLEMENTATION) y datos
*& globales del programa ZRMM_MASS_ARTICLE_CREATE.
*&---------------------------------------------------------------*

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

CONSTANTS gc_idoc_error_status TYPE string
  VALUE ',02,04,05,06,10,16,18,20,22,23,25,26,29,31,33,35,37,39,43,45,47,49,51,56,58,60,61,63,65,67,69,70,74,75,'.

CONSTANTS:
  BEGIN OF gc_status,
    ok      TYPE char1 VALUE 'S',   " Verde  - éxito
    error   TYPE char1 VALUE 'E',   " Rojo   - error
    warning TYPE char1 VALUE 'W',   " Amarillo - advertencia
    simul   TYPE char1 VALUE 'A',   " Azul/Gris - simulado
  END OF gc_status.

TYPES: ty_filename TYPE c LENGTH 255.

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
  p_file TYPE ty_filename OBLIGATORY.                  " Archivo Excel local (.xlsx)
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-002.
PARAMETERS:
  p_sim  TYPE xfeld AS CHECKBOX DEFAULT 'X',                " Modo simulación (2.3/2.4)
  p_stop TYPE xfeld AS CHECKBOX DEFAULT space.               " Detener en error (2.3)
SELECTION-SCREEN END OF BLOCK b2.

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



*&---------------------------------------------------------------*
*& Clase: lectura de archivo Excel (.xlsx) local
*&---------------------------------------------------------------*
CLASS lcl_excel_reader DEFINITION.
  PUBLIC SECTION.
    METHODS:
      constructor
        IMPORTING iv_file TYPE ty_filename,

      upload
        RETURNING VALUE(rv_ok) TYPE abap_bool,

      get_last_error
        RETURNING VALUE(rv_msg) TYPE string,

      get_sheet
        IMPORTING iv_sheet_name     TYPE string
        RETURNING VALUE(rt_sheet)   TYPE ty_excel_sheet.

  PRIVATE SECTION.
    DATA: mv_file      TYPE ty_filename,
          mo_xl_doc    TYPE REF TO cl_fdt_xl_spreadsheet,
          mv_xdata     TYPE xstring,
          mv_error_msg TYPE string.

    METHODS:
      read_frontend_file
        RETURNING VALUE(rv_ok) TYPE abap_bool.
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
  gv_stop_execution TYPE abap_bool,
  gt_unmapped_flds  TYPE STANDARD TABLE OF string WITH EMPTY KEY.
