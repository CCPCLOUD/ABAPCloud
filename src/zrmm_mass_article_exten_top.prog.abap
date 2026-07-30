*&---------------------------------------------------------------------*
*& Include ZRMM_MASS_ARTICLE_EXTEN_TOP
*& P158 - Ampliacion Masiva de Articulos (IDoc ARTMAS09)
*& Declaracion de tipos, tablas internas y pantalla de seleccion
*&---------------------------------------------------------------------*

*----------------------------------------------------------------------
* Constantes de hojas y layout del archivo Excel (layout final conciliado)
*----------------------------------------------------------------------
CONSTANTS:
  gc_sheet_articulos  TYPE string VALUE '01_ARTICULOS',
  gc_sheet_centros    TYPE string VALUE '02_CENTROS',
  gc_sheet_almacenes  TYPE string VALUE '03_ALMACENES',
  gc_sheet_valoracion TYPE string VALUE '06_VALORACION',
  gc_sheet_ventas     TYPE string VALUE '07_VENTAS_POS',
  gc_first_data_row   TYPE i      VALUE 8,
  gc_header_row       TYPE i      VALUE 7.

CONSTANTS:
  gc_attyp_simple    TYPE mara-attyp VALUE '0',
  gc_attyp_generico  TYPE mara-attyp VALUE '1',
  gc_attyp_variante  TYPE mara-attyp VALUE '2'.

CONSTANTS:
  gc_nivel_material   TYPE string VALUE 'Material',
  gc_nivel_centro      TYPE string VALUE 'Centro',
  gc_nivel_almacen     TYPE string VALUE 'Almacén',
  gc_nivel_valoracion  TYPE string VALUE 'Valoración',
  gc_nivel_ventas      TYPE string VALUE 'Ventas'.

*----------------------------------------------------------------------
* Estructuras "en crudo" tal cual se leen del Excel (fila 8 en adelante)
*----------------------------------------------------------------------
TYPES:
  BEGIN OF gty_s_articulo,
    row      TYPE i,
    material TYPE string,
  END OF gty_s_articulo,

  gtt_articulo TYPE STANDARD TABLE OF gty_s_articulo WITH NON-UNIQUE KEY row.

TYPES:
  BEGIN OF gty_s_centro,
    row              TYPE i,
    material         TYPE string,
    centro           TYPE string,
    grupo_compras    TYPE string,
    tipo_mrp         TYPE string,
    plazo_entrega    TYPE string,
    tipo_aprov       TYPE string,
    grupo_carga      TYPE string,
    verif_disponib   TYPE string,
    centro_beneficio TYPE string,
    pais_origen      TYPE string,
    perfil_distrib   TYPE string,
    stock_negativo   TYPE string,
    fuente_aprov     TYPE string,
    valor_redondeo   TYPE string,
  END OF gty_s_centro,

  gtt_centro TYPE STANDARD TABLE OF gty_s_centro WITH NON-UNIQUE KEY row.

TYPES:
  BEGIN OF gty_s_almacen,
    row      TYPE i,
    material TYPE string,
    centro   TYPE string,
    almacen  TYPE string,
  END OF gty_s_almacen,

  gtt_almacen TYPE STANDARD TABLE OF gty_s_almacen WITH NON-UNIQUE KEY row.

TYPES:
  BEGIN OF gty_s_valoracion,
    row                 TYPE i,
    material            TYPE string,
    area_valoracion     TYPE string,
    clase_valoracion    TYPE string,
    control_precio      TYPE string,
    precio_promedio     TYPE string,
    precio_estandar     TYPE string,
    unidad_precio       TYPE string,
  END OF gty_s_valoracion,

  gtt_valoracion TYPE STANDARD TABLE OF gty_s_valoracion WITH NON-UNIQUE KEY row.

TYPES:
  BEGIN OF gty_s_ventas,
    row                TYPE i,
    material           TYPE string,
    org_ventas         TYPE string,
    canal_distrib      TYPE string,
    categoria_item     TYPE string,
    grupo_imputacion   TYPE string,
    fecha_inicio       TYPE string,
    fecha_fin          TYPE string,
    material_ref_precio TYPE string,
    unidad_entrega     TYPE string,
  END OF gty_s_ventas,

  gtt_ventas TYPE STANDARD TABLE OF gty_s_ventas WITH NON-UNIQUE KEY row.

*----------------------------------------------------------------------
* Log de resultados (formato ALV solicitado por la FS: 2.4.8)
*----------------------------------------------------------------------
TYPES:
  BEGIN OF gty_s_log,
    icon      TYPE icon_d,
    estatus   TYPE char20,
    hoja      TYPE string,
    linea     TYPE i,
    material  TYPE matnr,
    nivel     TYPE string,
    clave_org TYPE string,
    idoc_no   TYPE edi_docnum,
    msgty     TYPE symsgty,
    mensaje   TYPE string,
  END OF gty_s_log,

  gtt_log TYPE STANDARD TABLE OF gty_s_log WITH NON-UNIQUE KEY hoja linea.

*----------------------------------------------------------------------
* Cache de informacion de artiiculo (evita relecturas de MARA)
*----------------------------------------------------------------------
TYPES:
  BEGIN OF gty_s_matinfo,
    material TYPE matnr,
    exists   TYPE abap_bool,
    lvorm    TYPE mara-lvorm,
    attyp    TYPE mara-attyp,
  END OF gty_s_matinfo,

  gtt_matinfo TYPE HASHED TABLE OF gty_s_matinfo WITH UNIQUE KEY material.

*----------------------------------------------------------------------
* Registro validado por material, agrupando todas sus ampliaciones
* (una entrada por material -> un IDoc ARTMAS09)
*----------------------------------------------------------------------
TYPES:
  BEGIN OF gty_s_centro_ok,
    centro           TYPE werks_d,
    grupo_compras    TYPE ekgrp,
    tipo_mrp         TYPE dismm,
    plazo_entrega    TYPE webaz,
    tipo_aprov       TYPE beskz,
    grupo_carga      TYPE ladgr,
    verif_disponib   TYPE mtvfp,
    centro_beneficio TYPE prctr,
    pais_origen      TYPE land1,
    perfil_distrib   TYPE char4,
    stock_negativo   TYPE char1,
    fuente_aprov     TYPE sobsl,
    valor_redondeo   TYPE bstrf,
    row              TYPE i,
  END OF gty_s_centro_ok,
  gtt_centro_ok TYPE STANDARD TABLE OF gty_s_centro_ok WITH NON-UNIQUE KEY centro.

TYPES:
  BEGIN OF gty_s_almacen_ok,
    centro  TYPE werks_d,
    almacen TYPE lgort_d,
    row     TYPE i,
  END OF gty_s_almacen_ok,
  gtt_almacen_ok TYPE STANDARD TABLE OF gty_s_almacen_ok WITH NON-UNIQUE KEY centro almacen.

TYPES:
  BEGIN OF gty_s_valoracion_ok,
    area_valoracion TYPE bwkey,
    clase_valoracion TYPE bklas,
    control_precio   TYPE vprsv,
    precio_promedio  TYPE verpr,
    precio_estandar  TYPE stprs,
    unidad_precio    TYPE peinh,
    row              TYPE i,
  END OF gty_s_valoracion_ok,
  gtt_valoracion_ok TYPE STANDARD TABLE OF gty_s_valoracion_ok WITH NON-UNIQUE KEY area_valoracion.

TYPES:
  BEGIN OF gty_s_ventas_ok,
    org_ventas          TYPE vkorg,
    canal_distrib       TYPE vtweg,
    categoria_item      TYPE string,
    grupo_imputacion    TYPE string,
    fecha_inicio        TYPE sy-datum,
    fecha_fin           TYPE sy-datum,
    material_ref_precio TYPE matnr,
    unidad_entrega      TYPE string,
    row                 TYPE i,
  END OF gty_s_ventas_ok,
  gtt_ventas_ok TYPE STANDARD TABLE OF gty_s_ventas_ok WITH NON-UNIQUE KEY org_ventas canal_distrib.

TYPES:
  BEGIN OF gty_s_material_ok,
    material    TYPE matnr,
    attyp       TYPE mara-attyp,
    t_centro    TYPE gtt_centro_ok,
    t_almacen   TYPE gtt_almacen_ok,
    t_valoracion TYPE gtt_valoracion_ok,
    t_ventas    TYPE gtt_ventas_ok,
  END OF gty_s_material_ok,

  gtt_material_ok TYPE STANDARD TABLE OF gty_s_material_ok WITH NON-UNIQUE KEY material.

*----------------------------------------------------------------------
* Tablas internas de trabajo
*----------------------------------------------------------------------
DATA:
  git_articulos  TYPE gtt_articulo,
  git_centros    TYPE gtt_centro,
  git_almacenes  TYPE gtt_almacen,
  git_valoracion TYPE gtt_valoracion,
  git_ventas     TYPE gtt_ventas,

  git_matinfo    TYPE gtt_matinfo,
  git_material_ok TYPE gtt_material_ok,

  git_log        TYPE gtt_log,

  gv_xdata       TYPE xstring,

  gv_count_total TYPE i,
  gv_count_ok    TYPE i,
  gv_count_error TYPE i,
  gv_count_warn  TYPE i.

*----------------------------------------------------------------------
* Pantalla de seleccion (2.4.2 - Propuesta de Pantalla Inicial)
*----------------------------------------------------------------------
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
PARAMETERS:
  p_file TYPE string LOWER CASE OBLIGATORY,
  p_sim  TYPE abap_bool AS CHECKBOX DEFAULT abap_true.
SELECTION-SCREEN END OF BLOCK b1.
