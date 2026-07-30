*&---------------------------------------------------------------------*
*& Report ZRMM_MASS_ARTICLE_EXTEN
*&---------------------------------------------------------------------*
*& P158 - Ampliacion Masiva de Articulos
*& Ticket #26515 - Necesidades Master Data
*&
*& Transaccion Z asignada: ZMM_ARTICLE_EXTEN
*&
*& Carga un archivo Excel local (.xlsx) y amplia articulos existentes
*& de SAP S/4HANA Retail (simples, genericos y variantes) a nuevos
*& centros, almacenes, areas de valoracion y areas de venta, mediante
*& la generacion y el procesamiento inbound del IDoc estandar ARTMAS09.
*&
*& No crea articulos, no modifica datos basicos ni la relacion
*& generico-variante (ver FS_P158_Ampliacion_Desarrollo, apartados
*& 2.3 Supuestos y 2.4.1 Alcance Funcional).
*&---------------------------------------------------------------------*
REPORT zrmm_mass_article_exten.

INCLUDE zrmm_mass_article_exten_top.
INCLUDE zrmm_mass_article_exten_sel.
INCLUDE zrmm_mass_article_exten_f01.
INCLUDE zrmm_mass_article_exten_f02.
INCLUDE zrmm_mass_article_exten_f03.
INCLUDE zrmm_mass_article_exten_f04.

START-OF-SELECTION.

  PERFORM upload_and_parse_excel USING p_file
                                  CHANGING gv_xdata.

  IF git_log IS NOT INITIAL AND
     git_articulos IS INITIAL.
    " Error fatal en la carga/estructura del archivo: no hay nada que procesar
    PERFORM display_log.
  ELSE.
    PERFORM build_material_cache.
    PERFORM validate_and_group_data.
    PERFORM process_idocs USING p_sim.
    PERFORM display_log.
  ENDIF.
