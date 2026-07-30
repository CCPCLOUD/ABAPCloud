*&---------------------------------------------------------------------*
*& Include ZRMM_MASS_ARTICLE_EXTEN_F02
*& Validaciones funcionales (FS 2.1 Dependencias / 2.3 Supuestos) y
*& agrupacion de las ampliaciones validas por material
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*&      Form  BUILD_MATERIAL_CACHE
*&  Construye la cache de articulos (existencia, borrado, tipo ATTYP)
*&---------------------------------------------------------------------*
FORM build_material_cache.

  DATA: lt_matnr TYPE HASHED TABLE OF matnr WITH UNIQUE KEY table_line,
        lv_matnr TYPE matnr.

  LOOP AT git_articulos INTO DATA(ls_art).
    PERFORM convert_matnr USING ls_art-material CHANGING lv_matnr.
    IF lv_matnr IS NOT INITIAL.
      INSERT lv_matnr INTO TABLE lt_matnr.
    ENDIF.
  ENDLOOP.

  IF lt_matnr IS INITIAL.
    RETURN.
  ENDIF.

  SELECT matnr, attyp, lvorm
    FROM mara
    INTO TABLE @DATA(lt_mara)
    FOR ALL ENTRIES IN @lt_matnr
    WHERE matnr = @lt_matnr-table_line.

  LOOP AT lt_matnr INTO lv_matnr.
    DATA(ls_info) = VALUE gty_s_matinfo( material = lv_matnr exists = abap_false ).
    READ TABLE lt_mara INTO DATA(ls_mara) WITH KEY matnr = lv_matnr.
    IF sy-subrc = 0.
      ls_info-exists = abap_true.
      ls_info-attyp  = ls_mara-attyp.
      ls_info-lvorm  = ls_mara-lvorm.
    ENDIF.
    INSERT ls_info INTO TABLE git_matinfo.
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  CONVERT_MATNR
*&---------------------------------------------------------------------*
FORM convert_matnr USING iu_raw TYPE string CHANGING cv_matnr TYPE matnr.

  CLEAR cv_matnr.
  IF iu_raw IS INITIAL.
    RETURN.
  ENDIF.

  CALL FUNCTION 'CONVERSION_EXIT_MATN1_INPUT'
    EXPORTING
      input  = iu_raw
    IMPORTING
      output = cv_matnr
    EXCEPTIONS
      OTHERS = 1.

  IF sy-subrc <> 0.
    cv_matnr = iu_raw.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  VALIDATE_AND_GROUP_DATA
*&---------------------------------------------------------------------*
FORM validate_and_group_data.

  DATA: lt_dup_centro    TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line,
        lt_dup_almacen   TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line,
        lt_dup_valorac   TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line,
        lt_dup_ventas    TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line,
        lt_dup_articulo  TYPE SORTED TABLE OF matnr  WITH UNIQUE KEY table_line.

  "---------------------------------------------------------------
  " 1) 01_ARTICULOS: existencia, no marcado para borrado, ATTYP
  "---------------------------------------------------------------
  LOOP AT git_articulos INTO DATA(ls_art).
    DATA(lv_matnr) = VALUE matnr( ).
    PERFORM convert_matnr USING ls_art-material CHANGING lv_matnr.

    IF lv_matnr IS INITIAL.
      PERFORM add_log USING icon_red_light 'Error' gc_sheet_articulos ls_art-row
                            space gc_nivel_material space 'E'
                            'Material vacío o con formato inválido.'.
      CONTINUE.
    ENDIF.

    IF lv_matnr IN lt_dup_articulo.
      PERFORM add_log USING icon_yellow_light 'Advertencia' gc_sheet_articulos ls_art-row
                            lv_matnr gc_nivel_material space 'W'
                            'Material duplicado en la hoja 01_ARTICULOS; se procesa una única vez.'.
      CONTINUE.
    ENDIF.
    INSERT lv_matnr INTO TABLE lt_dup_articulo.

    READ TABLE git_matinfo INTO DATA(ls_info) WITH TABLE KEY material = lv_matnr.
    IF sy-subrc <> 0 OR ls_info-exists = abap_false.
      PERFORM add_log USING icon_red_light 'Error' gc_sheet_articulos ls_art-row
                            lv_matnr gc_nivel_material space 'E'
                            'El artículo no existe en SAP. No se crean artículos nuevos (fuera de alcance).'.
      CONTINUE.
    ENDIF.

    IF ls_info-lvorm = abap_true.
      PERFORM add_log USING icon_red_light 'Error' gc_sheet_articulos ls_art-row
                            lv_matnr gc_nivel_material space 'E'
                            'El artículo está marcado para borrado.'.
      CONTINUE.
    ENDIF.

    IF ls_info-attyp <> gc_attyp_simple AND
       ls_info-attyp <> gc_attyp_generico AND
       ls_info-attyp <> gc_attyp_variante.
      PERFORM add_log USING icon_red_light 'Error' gc_sheet_articulos ls_art-row
                            lv_matnr gc_nivel_material space 'E'
                            'Categoría de artículo no soportada (sólo simple, genérico o variante).'.
      CONTINUE.
    ENDIF.

    " Material valido: se crea el registro agrupador (una entrada por material)
    READ TABLE git_material_ok TRANSPORTING NO FIELDS WITH KEY material = lv_matnr.
    IF sy-subrc <> 0.
      APPEND VALUE gty_s_material_ok( material = lv_matnr attyp = ls_info-attyp ) TO git_material_ok.
    ENDIF.
  ENDLOOP.

  "---------------------------------------------------------------
  " 2) 02_CENTROS
  "---------------------------------------------------------------
  LOOP AT git_centros INTO DATA(ls_ctr).
    PERFORM convert_matnr USING ls_ctr-material CHANGING lv_matnr.

    READ TABLE git_material_ok ASSIGNING FIELD-SYMBOL(<ls_mat>) WITH KEY material = lv_matnr.
    IF sy-subrc <> 0.
      PERFORM add_log USING icon_red_light 'Error' gc_sheet_centros ls_ctr-row
                            lv_matnr gc_nivel_centro ls_ctr-centro 'E'
                            'El artículo no es válido (ver hoja 01_ARTICULOS) o no fue informado allí.'.
      CONTINUE.
    ENDIF.

    DATA(lv_centro) = CONV werks_d( ls_ctr-centro ).
    IF lv_centro IS INITIAL.
      PERFORM add_log USING icon_red_light 'Error' gc_sheet_centros ls_ctr-row
                            lv_matnr gc_nivel_centro ls_ctr-centro 'E'
                            'Centro vacío.'.
      CONTINUE.
    ENDIF.

    SELECT SINGLE werks FROM t001w INTO @DATA(lv_werks_chk) WHERE werks = @lv_centro.
    IF sy-subrc <> 0.
      PERFORM add_log USING icon_red_light 'Error' gc_sheet_centros ls_ctr-row
                            lv_matnr gc_nivel_centro lv_centro 'E'
                            'El centro no existe en SAP (T001W).'.
      CONTINUE.
    ENDIF.

    DATA(lv_key_ctr) = |{ lv_matnr }-{ lv_centro }|.
    IF lv_key_ctr IN lt_dup_centro.
      PERFORM add_log USING icon_yellow_light 'Advertencia' gc_sheet_centros ls_ctr-row
                            lv_matnr gc_nivel_centro lv_centro 'W'
                            'Combinación material + centro duplicada en el archivo.'.
      CONTINUE.
    ENDIF.
    INSERT lv_key_ctr INTO TABLE lt_dup_centro.

    SELECT SINGLE matnr FROM marc INTO @DATA(lv_marc_chk)
      WHERE matnr = @lv_matnr AND werks = @lv_centro.
    IF sy-subrc = 0.
      PERFORM add_log USING icon_red_light 'Error' gc_sheet_centros ls_ctr-row
                            lv_matnr gc_nivel_centro lv_centro 'E'
                            'La extensión de centro ya existe.'.
      CONTINUE.
    ENDIF.

    DATA(ls_ctr_ok) = VALUE gty_s_centro_ok( centro = lv_centro row = ls_ctr-row ).
    ls_ctr_ok-grupo_compras    = ls_ctr-grupo_compras.
    ls_ctr_ok-tipo_mrp         = ls_ctr-tipo_mrp.
    ls_ctr_ok-plazo_entrega    = ls_ctr-plazo_entrega.
    ls_ctr_ok-tipo_aprov       = ls_ctr-tipo_aprov.
    ls_ctr_ok-grupo_carga      = ls_ctr-grupo_carga.
    ls_ctr_ok-verif_disponib   = ls_ctr-verif_disponib.
    ls_ctr_ok-centro_beneficio = ls_ctr-centro_beneficio.
    ls_ctr_ok-perfil_distrib   = ls_ctr-perfil_distrib.
    ls_ctr_ok-stock_negativo   = COND #( WHEN ls_ctr-stock_negativo CP '*X*' THEN 'X' ELSE space ).
    ls_ctr_ok-fuente_aprov     = ls_ctr-fuente_aprov.
    TRY.
        ls_ctr_ok-valor_redondeo = ls_ctr-valor_redondeo.
      CATCH cx_sy_conversion_no_number.
        CLEAR ls_ctr_ok-valor_redondeo.
    ENDTRY.

    IF ls_ctr-pais_origen IS NOT INITIAL.
      SELECT SINGLE land1 FROM t005 INTO @DATA(lv_land1) WHERE intca = @ls_ctr-pais_origen.
      IF sy-subrc = 0.
        ls_ctr_ok-pais_origen = lv_land1.
      ELSE.
        PERFORM add_log USING icon_yellow_light 'Advertencia' gc_sheet_centros ls_ctr-row
                              lv_matnr gc_nivel_centro lv_centro 'W'
                              |Código ISO de país de origen { ls_ctr-pais_origen } no reconocido (T005); campo omitido.|.
      ENDIF.
    ENDIF.

    IF ls_ctr-grupo_compras IS NOT INITIAL.
      SELECT SINGLE ekgrp FROM t024 INTO @DATA(lv_ekgrp_chk) WHERE ekgrp = @ls_ctr-grupo_compras.
      IF sy-subrc <> 0.
        PERFORM add_log USING icon_yellow_light 'Advertencia' gc_sheet_centros ls_ctr-row
                              lv_matnr gc_nivel_centro lv_centro 'W'
                              |Grupo de compras { ls_ctr-grupo_compras } no existe en T024; se envía igualmente para validación en el IDoc.|.
      ENDIF.
    ENDIF.

    APPEND ls_ctr_ok TO <ls_mat>-t_centro.
  ENDLOOP.

  "---------------------------------------------------------------
  " 3) 03_ALMACENES
  "---------------------------------------------------------------
  LOOP AT git_almacenes INTO DATA(ls_alm).
    PERFORM convert_matnr USING ls_alm-material CHANGING lv_matnr.

    READ TABLE git_material_ok ASSIGNING <ls_mat> WITH KEY material = lv_matnr.
    IF sy-subrc <> 0.
      PERFORM add_log USING icon_red_light 'Error' gc_sheet_almacenes ls_alm-row
                            lv_matnr gc_nivel_almacen ls_alm-almacen 'E'
                            'El artículo no es válido o no fue informado en 01_ARTICULOS.'.
      CONTINUE.
    ENDIF.

    lv_centro = CONV werks_d( ls_alm-centro ).
    DATA(lv_lgort) = CONV lgort_d( ls_alm-almacen ).

    IF lv_centro IS INITIAL OR lv_lgort IS INITIAL.
      PERFORM add_log USING icon_red_light 'Error' gc_sheet_almacenes ls_alm-row
                            lv_matnr gc_nivel_almacen |{ lv_centro }/{ lv_lgort }| 'E'
                            'Centro o almacén vacío.'.
      CONTINUE.
    ENDIF.

    READ TABLE <ls_mat>-t_centro TRANSPORTING NO FIELDS WITH KEY centro = lv_centro.
    IF sy-subrc <> 0.
      SELECT SINGLE matnr FROM marc INTO @DATA(lv_marc_exists)
        WHERE matnr = @lv_matnr AND werks = @lv_centro.
      IF sy-subrc <> 0.
        PERFORM add_log USING icon_red_light 'Error' gc_sheet_almacenes ls_alm-row
                              lv_matnr gc_nivel_almacen |{ lv_centro }/{ lv_lgort }| 'E'
                              'El centro debe existir previamente o incluirse en la hoja 02_CENTROS del mismo archivo.'.
        CONTINUE.
      ENDIF.
    ENDIF.

    SELECT SINGLE werks FROM t001l INTO @DATA(lv_lgort_chk)
      WHERE werks = @lv_centro AND lgort = @lv_lgort.
    IF sy-subrc <> 0.
      PERFORM add_log USING icon_red_light 'Error' gc_sheet_almacenes ls_alm-row
                            lv_matnr gc_nivel_almacen |{ lv_centro }/{ lv_lgort }| 'E'
                            'El almacén no existe para el centro indicado (T001L).'.
      CONTINUE.
    ENDIF.

    DATA(lv_key_alm) = |{ lv_matnr }-{ lv_centro }-{ lv_lgort }|.
    IF lv_key_alm IN lt_dup_almacen.
      PERFORM add_log USING icon_yellow_light 'Advertencia' gc_sheet_almacenes ls_alm-row
                            lv_matnr gc_nivel_almacen |{ lv_centro }/{ lv_lgort }| 'W'
                            'Combinación material + centro + almacén duplicada en el archivo.'.
      CONTINUE.
    ENDIF.
    INSERT lv_key_alm INTO TABLE lt_dup_almacen.

    SELECT SINGLE matnr FROM mard INTO @DATA(lv_mard_chk)
      WHERE matnr = @lv_matnr AND werks = @lv_centro AND lgort = @lv_lgort.
    IF sy-subrc = 0.
      PERFORM add_log USING icon_red_light 'Error' gc_sheet_almacenes ls_alm-row
                            lv_matnr gc_nivel_almacen |{ lv_centro }/{ lv_lgort }| 'E'
                            'La extensión de almacén ya existe.'.
      CONTINUE.
    ENDIF.

    APPEND VALUE gty_s_almacen_ok( centro = lv_centro almacen = lv_lgort row = ls_alm-row )
      TO <ls_mat>-t_almacen.
  ENDLOOP.

  "---------------------------------------------------------------
  " 4) 06_VALORACION
  "---------------------------------------------------------------
  LOOP AT git_valoracion INTO DATA(ls_val).
    PERFORM convert_matnr USING ls_val-material CHANGING lv_matnr.

    READ TABLE git_material_ok ASSIGNING <ls_mat> WITH KEY material = lv_matnr.
    IF sy-subrc <> 0.
      PERFORM add_log USING icon_red_light 'Error' gc_sheet_valoracion ls_val-row
                            lv_matnr gc_nivel_valoracion ls_val-area_valoracion 'E'
                            'El artículo no es válido o no fue informado en 01_ARTICULOS.'.
      CONTINUE.
    ENDIF.

    DATA(lv_bwkey) = CONV bwkey( ls_val-area_valoracion ).
    IF lv_bwkey IS INITIAL.
      PERFORM add_log USING icon_red_light 'Error' gc_sheet_valoracion ls_val-row
                            lv_matnr gc_nivel_valoracion lv_bwkey 'E'
                            'Área de valoración vacía.'.
      CONTINUE.
    ENDIF.

    SELECT SINGLE bwkey FROM t001k INTO @DATA(lv_bwkey_chk) WHERE bwkey = @lv_bwkey.
    IF sy-subrc <> 0.
      PERFORM add_log USING icon_red_light 'Error' gc_sheet_valoracion ls_val-row
                            lv_matnr gc_nivel_valoracion lv_bwkey 'E'
                            'El área de valoración no existe en SAP (T001K).'.
      CONTINUE.
    ENDIF.

    DATA(lv_key_val) = |{ lv_matnr }-{ lv_bwkey }|.
    IF lv_key_val IN lt_dup_valorac.
      PERFORM add_log USING icon_yellow_light 'Advertencia' gc_sheet_valoracion ls_val-row
                            lv_matnr gc_nivel_valoracion lv_bwkey 'W'
                            'Combinación material + área de valoración duplicada en el archivo.'.
      CONTINUE.
    ENDIF.
    INSERT lv_key_val INTO TABLE lt_dup_valorac.

    SELECT SINGLE matnr FROM mbew INTO @DATA(lv_mbew_chk)
      WHERE matnr = @lv_matnr AND bwkey = @lv_bwkey.
    IF sy-subrc = 0.
      PERFORM add_log USING icon_red_light 'Error' gc_sheet_valoracion ls_val-row
                            lv_matnr gc_nivel_valoracion lv_bwkey 'E'
                            'La valoración ya existe para esta área.'.
      CONTINUE.
    ENDIF.

    DATA(ls_val_ok) = VALUE gty_s_valoracion_ok( area_valoracion = lv_bwkey row = ls_val-row ).
    ls_val_ok-clase_valoracion = ls_val-clase_valoracion.
    ls_val_ok-unidad_precio    = ls_val-unidad_precio.

    CASE ls_val-control_precio.
      WHEN 'V' OR 'S'.
        ls_val_ok-control_precio = ls_val-control_precio.
      WHEN OTHERS.
        PERFORM add_log USING icon_red_light 'Error' gc_sheet_valoracion ls_val-row
                              lv_matnr gc_nivel_valoracion lv_bwkey 'E'
                              'Control de precio inválido; use V (móvil) o S (estándar).'.
        CONTINUE.
    ENDCASE.

    IF ls_val_ok-control_precio = 'V' AND ls_val-precio_promedio IS INITIAL.
      PERFORM add_log USING icon_red_light 'Error' gc_sheet_valoracion ls_val-row
                            lv_matnr gc_nivel_valoracion lv_bwkey 'E'
                            'Control de precio V requiere precio promedio móvil.'.
      CONTINUE.
    ENDIF.

    IF ls_val_ok-control_precio = 'S' AND ls_val-precio_estandar IS INITIAL.
      PERFORM add_log USING icon_red_light 'Error' gc_sheet_valoracion ls_val-row
                            lv_matnr gc_nivel_valoracion lv_bwkey 'E'
                            'Control de precio S requiere precio estándar.'.
      CONTINUE.
    ENDIF.

    ls_val_ok-precio_promedio = ls_val-precio_promedio.
    ls_val_ok-precio_estandar = ls_val-precio_estandar.

    APPEND ls_val_ok TO <ls_mat>-t_valoracion.
  ENDLOOP.

  "---------------------------------------------------------------
  " 5) 07_VENTAS_POS
  "---------------------------------------------------------------
  LOOP AT git_ventas INTO DATA(ls_vta).
    PERFORM convert_matnr USING ls_vta-material CHANGING lv_matnr.

    READ TABLE git_material_ok ASSIGNING <ls_mat> WITH KEY material = lv_matnr.
    IF sy-subrc <> 0.
      PERFORM add_log USING icon_red_light 'Error' gc_sheet_ventas ls_vta-row
                            lv_matnr gc_nivel_ventas |{ ls_vta-org_ventas }/{ ls_vta-canal_distrib }| 'E'
                            'El artículo no es válido o no fue informado en 01_ARTICULOS.'.
      CONTINUE.
    ENDIF.

    DATA(lv_vkorg) = CONV vkorg( ls_vta-org_ventas ).
    DATA(lv_vtweg) = CONV vtweg( ls_vta-canal_distrib ).

    IF lv_vkorg IS INITIAL OR lv_vtweg IS INITIAL.
      PERFORM add_log USING icon_red_light 'Error' gc_sheet_ventas ls_vta-row
                            lv_matnr gc_nivel_ventas |{ lv_vkorg }/{ lv_vtweg }| 'E'
                            'Organización de ventas o canal de distribución vacío.'.
      CONTINUE.
    ENDIF.

    SELECT SINGLE vkorg FROM tvko INTO @DATA(lv_vkorg_chk) WHERE vkorg = @lv_vkorg.
    IF sy-subrc <> 0.
      PERFORM add_log USING icon_red_light 'Error' gc_sheet_ventas ls_vta-row
                            lv_matnr gc_nivel_ventas |{ lv_vkorg }/{ lv_vtweg }| 'E'
                            'La organización de ventas no existe en SAP (TVKO).'.
      CONTINUE.
    ENDIF.

    SELECT SINGLE vkorg FROM tvkov INTO @DATA(lv_tvkov_chk)
      WHERE vkorg = @lv_vkorg AND vtweg = @lv_vtweg.
    IF sy-subrc <> 0.
      PERFORM add_log USING icon_red_light 'Error' gc_sheet_ventas ls_vta-row
                            lv_matnr gc_nivel_ventas |{ lv_vkorg }/{ lv_vtweg }| 'E'
                            'La combinación organización de ventas / canal de distribución no es válida (TVKOV).'.
      CONTINUE.
    ENDIF.

    DATA(lv_key_vta) = |{ lv_matnr }-{ lv_vkorg }-{ lv_vtweg }|.
    IF lv_key_vta IN lt_dup_ventas.
      PERFORM add_log USING icon_yellow_light 'Advertencia' gc_sheet_ventas ls_vta-row
                            lv_matnr gc_nivel_ventas |{ lv_vkorg }/{ lv_vtweg }| 'W'
                            'Combinación material + organización de ventas + canal duplicada en el archivo.'.
      CONTINUE.
    ENDIF.
    INSERT lv_key_vta INTO TABLE lt_dup_ventas.

    SELECT SINGLE matnr FROM mvke INTO @DATA(lv_mvke_chk)
      WHERE matnr = @lv_matnr AND vkorg = @lv_vkorg AND vtweg = @lv_vtweg.
    IF sy-subrc = 0.
      PERFORM add_log USING icon_red_light 'Error' gc_sheet_ventas ls_vta-row
                            lv_matnr gc_nivel_ventas |{ lv_vkorg }/{ lv_vtweg }| 'E'
                            'La extensión al área de ventas ya existe.'.
      CONTINUE.
    ENDIF.

    DATA(ls_vta_ok) = VALUE gty_s_ventas_ok( org_ventas = lv_vkorg canal_distrib = lv_vtweg row = ls_vta-row ).
    ls_vta_ok-categoria_item   = ls_vta-categoria_item.
    ls_vta_ok-grupo_imputacion = ls_vta-grupo_imputacion.
    ls_vta_ok-unidad_entrega   = ls_vta-unidad_entrega.

    IF ls_vta-fecha_inicio IS NOT INITIAL.
      TRY.
          ls_vta_ok-fecha_inicio = ls_vta-fecha_inicio.
        CATCH cx_sy_conversion_no_number.
          PERFORM add_log USING icon_yellow_light 'Advertencia' gc_sheet_ventas ls_vta-row
                                lv_matnr gc_nivel_ventas |{ lv_vkorg }/{ lv_vtweg }| 'W'
                                'Fecha de inicio con formato inválido (use AAAAMMDD); campo omitido.'.
      ENDTRY.
    ENDIF.

    IF ls_vta-fecha_fin IS NOT INITIAL.
      TRY.
          ls_vta_ok-fecha_fin = ls_vta-fecha_fin.
        CATCH cx_sy_conversion_no_number.
          PERFORM add_log USING icon_yellow_light 'Advertencia' gc_sheet_ventas ls_vta-row
                                lv_matnr gc_nivel_ventas |{ lv_vkorg }/{ lv_vtweg }| 'W'
                                'Fecha de fin con formato inválido (use AAAAMMDD); campo omitido.'.
      ENDTRY.
    ENDIF.

    IF ls_vta_ok-fecha_inicio IS NOT INITIAL AND ls_vta_ok-fecha_fin IS NOT INITIAL
       AND ls_vta_ok-fecha_fin < ls_vta_ok-fecha_inicio.
      PERFORM add_log USING icon_red_light 'Error' gc_sheet_ventas ls_vta-row
                            lv_matnr gc_nivel_ventas |{ lv_vkorg }/{ lv_vtweg }| 'E'
                            'La fecha de fin no puede ser menor que la fecha de inicio.'.
      CONTINUE.
    ENDIF.

    IF ls_vta-material_ref_precio IS NOT INITIAL.
      PERFORM convert_matnr USING ls_vta-material_ref_precio CHANGING ls_vta_ok-material_ref_precio.
    ELSEIF <ls_mat>-attyp = gc_attyp_variante.
      PERFORM add_log USING icon_yellow_light 'Advertencia' gc_sheet_ventas ls_vta-row
                            lv_matnr gc_nivel_ventas |{ lv_vkorg }/{ lv_vtweg }| 'W'
                            'Material de referencia de precio no informado para una variante; validar regla de negocio con Master Data antes de confirmar.'.
    ENDIF.

    APPEND ls_vta_ok TO <ls_mat>-t_ventas.
  ENDLOOP.

  "---------------------------------------------------------------
  " 6) Materiales sin ninguna ampliacion valida -> se descartan
  "---------------------------------------------------------------
  LOOP AT git_material_ok INTO DATA(ls_final) WHERE t_centro     IS INITIAL
                                                 AND t_almacen    IS INITIAL
                                                 AND t_valoracion IS INITIAL
                                                 AND t_ventas     IS INITIAL.
    PERFORM add_log USING icon_yellow_light 'Advertencia' gc_sheet_articulos 0
                          ls_final-material gc_nivel_material space 'W'
                          'El artículo no tiene ninguna ampliación válida informada; no se genera IDoc.'.
    DELETE git_material_ok WHERE material = ls_final-material.
  ENDLOOP.

ENDFORM.
