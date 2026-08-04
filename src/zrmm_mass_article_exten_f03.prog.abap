*&---------------------------------------------------------------------*
*& Include ZRMM_MASS_ARTICLE_EXTEN_F03
*& Construccion y procesamiento del IDoc ARTMAS09 por articulo
*& (FS 2.4.4 Mapeo Excel a IDOC / 2.4.5 Estructura IDOC)
*&
*& Nota tecnica: los nombres de segmento/campo (E1BPE1..., MESTYP,
*& IDOCTYP) provienen del mapeo funcional acordado en la FS. Se deben
*& verificar en WE60/WE30/SE11 antes de trasladar a un sistema
*& productivo, tal como indica el propio documento.
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*&      Form  PROCESS_IDOCS
*&---------------------------------------------------------------------*
FORM process_idocs USING iu_sim TYPE abap_bool.

  IF iu_sim = abap_false.
    PERFORM read_edi_partner_config.
  ENDIF.

  LOOP AT git_material_ok INTO DATA(ls_mat).
    PERFORM process_one_material USING ls_mat iu_sim.
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  READ_EDI_PARTNER_CONFIG
*&  Lee de TVARVC (variantes tipo S) el tipo/numero de interlocutor y
*&  la puerta a usar en el registro de control del IDoc
*&---------------------------------------------------------------------*
FORM read_edi_partner_config.

  DATA: lv_tp_int_edi  TYPE tvarvc-low,
        lv_n_inter_edi TYPE tvarvc-low,
        lv_puerta      TYPE tvarvc-low.

  SELECT SINGLE low FROM tvarvc INTO lv_tp_int_edi
    WHERE name = gc_tvarvc_tp_int_edi AND type = 'S'.
  SELECT SINGLE low FROM tvarvc INTO lv_n_inter_edi
    WHERE name = gc_tvarvc_n_inter_edi AND type = 'S'.
  SELECT SINGLE low FROM tvarvc INTO lv_puerta
    WHERE name = gc_tvarvc_puerta AND type = 'S'.

  gv_sndprt = lv_tp_int_edi.
  gv_rcvprt = lv_tp_int_edi.
  gv_sndprn = lv_n_inter_edi.
  gv_rcvprn = lv_n_inter_edi.
  gv_sndpor = lv_puerta.

  IF lv_tp_int_edi IS INITIAL OR lv_n_inter_edi IS INITIAL OR lv_puerta IS INITIAL.
    DATA(lv_msg) = |Falta configurar una o más variantes en TVARVC ({ gc_tvarvc_tp_int_edi }/|
                && |{ gc_tvarvc_n_inter_edi }/{ gc_tvarvc_puerta }); el registro de control del IDoc quedará incompleto.|.
    PERFORM add_log USING icon_yellow_light 'Advertencia' gc_sheet_articulos 0
                          space gc_nivel_material space 'W' lv_msg gc_no_docnum.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  PROCESS_ONE_MATERIAL
*&  Un IDoc ARTMAS09 por material, agrupando todas sus ampliaciones
*&---------------------------------------------------------------------*
FORM process_one_material USING iu_mat TYPE gty_s_material_ok
                                 iu_sim TYPE abap_bool.

  DATA: lt_edidd     TYPE STANDARD TABLE OF edi_dd40,
        ls_edidd     TYPE edi_dd40,
        lt_keys      TYPE string_table,
        lv_no_docnum TYPE edi_docnum.

  "-----------------------------------------------------------------
  " E1BPE1MATHEAD - identificacion del articulo que se amplia
  "-----------------------------------------------------------------
  DATA: ls_mathead TYPE e1bpe1mathead.
  ls_mathead-material = iu_mat-material.

  CLEAR ls_edidd.
  ls_edidd-segnam = 'E1BPE1MATHEAD'.
  ls_edidd-sdata  = ls_mathead.
  APPEND ls_edidd TO lt_edidd.

  "-----------------------------------------------------------------
  " Ampliacion a centros: por cada centro, E1BPE1MARCRT seguido
  " inmediatamente de su hijo E1BPE1MARCRT1; y despues, en bloque
  " aparte (al final de todos los pares), TODOS los E1BPE1MARCRTX
  " (segmento de indicadores real) - secuencia confirmada contra un
  " IDoc ARTMAS09 real generado por otra interfaz ya existente.
  "-----------------------------------------------------------------
  DATA: lt_marcrtx TYPE STANDARD TABLE OF e1bpe1marcrtx.

  LOOP AT iu_mat-t_centro INTO DATA(ls_ctr).
    DATA: ls_marcrt  TYPE e1bpe1marcrt,
          ls_marcrt1 TYPE e1bpe1marcrt1,
          ls_marcrtx TYPE e1bpe1marcrtx.
    CLEAR: ls_marcrt, ls_marcrt1, ls_marcrtx.

    ls_marcrt-material    = iu_mat-material.
    ls_marcrt-plant       = ls_ctr-centro.
    ls_marcrt-pur_group   = ls_ctr-grupo_compras.
    ls_marcrt-mrp_type    = ls_ctr-tipo_mrp.
    ls_marcrt-plnd_delry  = ls_ctr-plazo_entrega.
    ls_marcrt-proc_type   = ls_ctr-tipo_aprov.
    ls_marcrt-loadinggrp  = ls_ctr-grupo_carga.
    ls_marcrt-availcheck  = ls_ctr-verif_disponib.
    ls_marcrt-profit_ctr  = ls_ctr-centro_beneficio.
    ls_marcrt-countryori  = ls_ctr-pais_origen.
    ls_marcrt-distr_prof  = ls_ctr-perfil_distrib.
    ls_marcrt-neg_stocks  = ls_ctr-stock_negativo.
    ls_marcrt-sup_source  = ls_ctr-fuente_aprov.
    ls_marcrt-round_val   = ls_ctr-valor_redondeo.

    CLEAR lt_keys.
    APPEND `MATERIAL` TO lt_keys.
    APPEND `PLANT` TO lt_keys.
    PERFORM mark_changed_fields USING lt_keys CHANGING ls_marcrt ls_marcrt1.
    PERFORM mark_changed_fields USING lt_keys CHANGING ls_marcrt ls_marcrtx.

    CLEAR ls_edidd.
    ls_edidd-segnam = 'E1BPE1MARCRT'.
    ls_edidd-sdata  = ls_marcrt.
    APPEND ls_edidd TO lt_edidd.

    CLEAR ls_edidd.
    ls_edidd-segnam = 'E1BPE1MARCRT1'.
    ls_edidd-sdata  = ls_marcrt1.
    APPEND ls_edidd TO lt_edidd.

    APPEND ls_marcrtx TO lt_marcrtx.
  ENDLOOP.

  LOOP AT lt_marcrtx INTO ls_marcrtx.
    CLEAR ls_edidd.
    ls_edidd-segnam = 'E1BPE1MARCRTX'.
    ls_edidd-sdata  = ls_marcrtx.
    APPEND ls_edidd TO lt_edidd.
  ENDLOOP.

  "-----------------------------------------------------------------
  " Ampliacion a almacenes: primero TODOS los E1BPE1MARDRT, despues
  " TODOS los E1BPE1MARDRTX en bloque aparte (MARDRT no tiene un hijo
  " intermedio como MARCRT1; su X va agrupada al final).
  "-----------------------------------------------------------------
  DATA: lt_mardrtx TYPE STANDARD TABLE OF e1bpe1mardrtx.

  LOOP AT iu_mat-t_almacen INTO DATA(ls_alm).
    DATA: ls_mardrt  TYPE e1bpe1mardrt,
          ls_mardrtx TYPE e1bpe1mardrtx.
    CLEAR: ls_mardrt, ls_mardrtx.

    ls_mardrt-material = iu_mat-material.
    ls_mardrt-plant    = ls_alm-centro.
    ls_mardrt-stge_loc = ls_alm-almacen.

    CLEAR lt_keys.
    APPEND `MATERIAL` TO lt_keys.
    APPEND `PLANT` TO lt_keys.
    APPEND `STGE_LOC` TO lt_keys.
    PERFORM mark_changed_fields USING lt_keys CHANGING ls_mardrt ls_mardrtx.

    CLEAR ls_edidd.
    ls_edidd-segnam = 'E1BPE1MARDRT'.
    ls_edidd-sdata  = ls_mardrt.
    APPEND ls_edidd TO lt_edidd.

    APPEND ls_mardrtx TO lt_mardrtx.
  ENDLOOP.

  LOOP AT lt_mardrtx INTO ls_mardrtx.
    CLEAR ls_edidd.
    ls_edidd-segnam = 'E1BPE1MARDRTX'.
    ls_edidd-sdata  = ls_mardrtx.
    APPEND ls_edidd TO lt_edidd.
  ENDLOOP.

  "-----------------------------------------------------------------
  " Datos de valoracion: primero TODOS los E1BPE1MBEWRT, despues
  " TODOS los E1BPE1MBEWRTX en bloque aparte.
  "-----------------------------------------------------------------
  DATA: lt_mbewrtx TYPE STANDARD TABLE OF e1bpe1mbewrtx.

  LOOP AT iu_mat-t_valoracion INTO DATA(ls_val).
    DATA: ls_mbewrt  TYPE e1bpe1mbewrt,
          ls_mbewrtx TYPE e1bpe1mbewrtx.
    CLEAR: ls_mbewrt, ls_mbewrtx.

    ls_mbewrt-material   = iu_mat-material.
    ls_mbewrt-val_area   = ls_val-area_valoracion.
    ls_mbewrt-val_class  = ls_val-clase_valoracion.
    ls_mbewrt-price_ctrl = ls_val-control_precio.
    ls_mbewrt-moving_pr  = ls_val-precio_promedio.
    ls_mbewrt-std_price  = ls_val-precio_estandar.
    ls_mbewrt-price_unit = ls_val-unidad_precio.

    CLEAR lt_keys.
    APPEND `MATERIAL` TO lt_keys.
    APPEND `VAL_AREA` TO lt_keys.
    PERFORM mark_changed_fields USING lt_keys CHANGING ls_mbewrt ls_mbewrtx.

    CLEAR ls_edidd.
    ls_edidd-segnam = 'E1BPE1MBEWRT'.
    ls_edidd-sdata  = ls_mbewrt.
    APPEND ls_edidd TO lt_edidd.

    APPEND ls_mbewrtx TO lt_mbewrtx.
  ENDLOOP.

  LOOP AT lt_mbewrtx INTO ls_mbewrtx.
    CLEAR ls_edidd.
    ls_edidd-segnam = 'E1BPE1MBEWRTX'.
    ls_edidd-sdata  = ls_mbewrtx.
    APPEND ls_edidd TO lt_edidd.
  ENDLOOP.

  "-----------------------------------------------------------------
  " Area de ventas: primero TODOS los E1BPE1MVKERT, despues TODOS
  " los E1BPE1MVKERTX en bloque aparte.
  "-----------------------------------------------------------------
  DATA: lt_mvkertx TYPE STANDARD TABLE OF e1bpe1mvkertx.

  LOOP AT iu_mat-t_ventas INTO DATA(ls_vta).
    DATA: ls_mvkert  TYPE e1bpe1mvkert,
          ls_mvkertx TYPE e1bpe1mvkertx.
    CLEAR: ls_mvkert, ls_mvkertx.

    ls_mvkert-material    = iu_mat-material.
    ls_mvkert-sales_org   = ls_vta-org_ventas.
    ls_mvkert-distr_chan  = ls_vta-canal_distrib.
    ls_mvkert-item_cat    = ls_vta-categoria_item.
    ls_mvkert-acct_assgt  = ls_vta-grupo_imputacion.
    ls_mvkert-dely_unit   = ls_vta-unidad_entrega.
    ls_mvkert-pr_ref_mat  = ls_vta-material_ref_precio.

    IF ls_vta-fecha_inicio IS NOT INITIAL.
      ls_mvkert-list_st_fr = ls_vta-fecha_inicio.
      ls_mvkert-list_dc_fr = ls_vta-fecha_inicio.
      ls_mvkert-sell_st_fr = ls_vta-fecha_inicio.
      ls_mvkert-sell_dc_fr = ls_vta-fecha_inicio.
    ENDIF.
    IF ls_vta-fecha_fin IS NOT INITIAL.
      ls_mvkert-list_st_to = ls_vta-fecha_fin.
      ls_mvkert-list_dc_to = ls_vta-fecha_fin.
      ls_mvkert-sell_st_to = ls_vta-fecha_fin.
      ls_mvkert-sell_dc_to = ls_vta-fecha_fin.
    ENDIF.

    CLEAR lt_keys.
    APPEND `MATERIAL` TO lt_keys.
    APPEND `SALES_ORG` TO lt_keys.
    APPEND `DISTR_CHAN` TO lt_keys.
    PERFORM mark_changed_fields USING lt_keys CHANGING ls_mvkert ls_mvkertx.

    CLEAR ls_edidd.
    ls_edidd-segnam = 'E1BPE1MVKERT'.
    ls_edidd-sdata  = ls_mvkert.
    APPEND ls_edidd TO lt_edidd.

    APPEND ls_mvkertx TO lt_mvkertx.
  ENDLOOP.

  LOOP AT lt_mvkertx INTO ls_mvkertx.
    CLEAR ls_edidd.
    ls_edidd-segnam = 'E1BPE1MVKERTX'.
    ls_edidd-sdata  = ls_mvkertx.
    APPEND ls_edidd TO lt_edidd.
  ENDLOOP.

  "-----------------------------------------------------------------
  " Modo simulacion: no se genera ni procesa IDoc
  "-----------------------------------------------------------------
  IF iu_sim = abap_true.
    PERFORM log_material_result USING iu_mat lv_no_docnum 'S'
                                      'Registro(s) validado(s) correctamente. IDoc no procesado (modo simulación).'.
    RETURN.
  ENDIF.

  "-----------------------------------------------------------------
  " Generacion y despacho del IDoc via MASTER_IDOC_DISTRIBUTE
  "-----------------------------------------------------------------
  PERFORM dispatch_idoc USING lt_edidd iu_mat.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  MARK_CHANGED_FIELDS
*&  Genera el segmento "X" (indicadores de cambio) de forma generica:
*&  por cada campo de datos no vacio (excluyendo la llave), marca 'X'
*&  en el campo homonimo del segmento de indicadores.
*&---------------------------------------------------------------------*
FORM mark_changed_fields USING it_key_fields TYPE string_table
                         CHANGING cs_data  TYPE any
                                  cs_flags TYPE any.

  DATA: lo_struct TYPE REF TO cl_abap_structdescr,
        lt_comp   TYPE cl_abap_structdescr=>component_table.

  lo_struct ?= cl_abap_typedescr=>describe_by_data( cs_data ).
  lt_comp = lo_struct->get_components( ).

  LOOP AT lt_comp INTO DATA(ls_comp).
    IF line_exists( it_key_fields[ table_line = ls_comp-name ] ).
      CONTINUE.
    ENDIF.

    FIELD-SYMBOLS: <lv_data> TYPE any,
                   <lv_flag> TYPE any.
    ASSIGN COMPONENT ls_comp-name OF STRUCTURE cs_data TO <lv_data>.
    IF <lv_data> IS NOT ASSIGNED OR <lv_data> IS INITIAL.
      CONTINUE.
    ENDIF.

    ASSIGN COMPONENT ls_comp-name OF STRUCTURE cs_flags TO <lv_flag>.
    IF <lv_flag> IS ASSIGNED.
      <lv_flag> = 'X'.
    ENDIF.
    UNASSIGN: <lv_data>, <lv_flag>.
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  DISPATCH_IDOC
*&  Genera el IDoc ARTMAS09 de ENTRADA (EDI_DC40-DIRECT = '2') mediante
*&  IDOC_INBOUND_SINGLE y actualiza el log con el numero de IDoc
*&  generado o el error de despacho.
*&
*&  Firma verificada en SE37 (sistema destino):
*&    IMPORT   PI_IDOC_CONTROL_REC_40 LIKE EDI_DC40
*&             PI_DO_COMMIT           LIKE EDI_HELP-DO_COMMIT OPTIONAL (default 'X')
*&    EXPORT   PE_IDOC_NUMBER               LIKE EDIDC-DOCNUM
*&             PE_ERROR_PRIOR_TO_APPLICATION LIKE EDI_HELP-ERROR_FLAG
*&    TABLES   PT_IDOC_DATA_RECORDS_40 LIKE EDI_DD40
*&---------------------------------------------------------------------*
FORM dispatch_idoc USING it_edidd TYPE STANDARD TABLE
                         iu_mat   TYPE gty_s_material_ok.

  DATA: ls_control    TYPE edi_dc40,
        lv_no_docnum  TYPE edi_docnum,
        lv_pe_docnum  TYPE edidc-docnum,
        lv_error_flag TYPE edi_help-error_flag.

  " Interlocutor emisor/receptor y puerta: configurados via TVARVC
  " (ver READ_EDI_PARTNER_CONFIG), tal como en desarrollos previos.
  ls_control-mestyp = 'ARTMAS'.
  ls_control-idoctyp = 'ARTMAS09'.
  ls_control-direct = '2'.               " '2' = IDoc de ENTRADA (inbound)
  ls_control-sndprt = gv_sndprt.
  ls_control-sndprn = gv_sndprn.
  ls_control-rcvprt = gv_rcvprt.
  ls_control-rcvprn = gv_rcvprn.
  ls_control-sndpor = gv_sndpor.

  CALL FUNCTION 'IDOC_INBOUND_SINGLE'
    EXPORTING
      pi_idoc_control_rec_40        = ls_control
      pi_do_commit                   = 'X'
    IMPORTING
      pe_idoc_number                 = lv_pe_docnum
      pe_error_prior_to_application  = lv_error_flag
    TABLES
      pt_idoc_data_records_40        = it_edidd
    EXCEPTIONS
      OTHERS                         = 1.

  IF sy-subrc <> 0.
    DATA(lv_msg) = |Error al generar/procesar el IDoc ARTMAS09 de entrada (IDOC_INBOUND_SINGLE rc={ sy-subrc }).|.
    PERFORM log_material_result USING iu_mat lv_no_docnum 'E' lv_msg.
    RETURN.
  ENDIF.

  DATA(lv_docnum) = lv_pe_docnum.

  IF lv_docnum IS INITIAL.
    PERFORM log_material_result USING iu_mat lv_no_docnum 'E'
                                      'No fue posible generar el IDoc; revisar WE02/WE05.'.
  ELSEIF lv_error_flag = abap_true.
    PERFORM log_material_result USING iu_mat lv_docnum 'W'
                                      'IDoc de entrada generado, pero con error antes de llegar a la aplicación; revisar WE02/WE05.'.
  ELSE.
    PERFORM log_material_result USING iu_mat lv_docnum 'S'
                                      'Artículo ampliado correctamente. IDoc de entrada procesado (ver WE05/WE02).'.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  LOG_MATERIAL_RESULT
*&  Escribe una linea de log por cada ampliacion (centro/almacen/
*&  valoracion/ventas) del material, con el mismo resultado e IDoc
*&---------------------------------------------------------------------*
FORM log_material_result USING iu_mat     TYPE gty_s_material_ok
                                iu_docnum  TYPE edi_docnum
                                iu_msgty   TYPE symsgty
                                iu_mensaje TYPE string.

  DATA: lv_icon TYPE icon_d,
        lv_est  TYPE char20.

  CASE iu_msgty.
    WHEN 'S'.
      lv_icon = icon_green_light.
      lv_est  = 'Verde'.
    WHEN 'W'.
      lv_icon = icon_yellow_light.
      lv_est  = 'Amarillo'.
    WHEN OTHERS.
      lv_icon = icon_red_light.
      lv_est  = 'Rojo'.
  ENDCASE.

  DATA(lv_any_line) = abap_false.
  DATA: lv_clave TYPE string.

  LOOP AT iu_mat-t_centro INTO DATA(ls_ctr).
    lv_any_line = abap_true.
    PERFORM add_log USING lv_icon lv_est gc_sheet_centros ls_ctr-row
                          iu_mat-material gc_nivel_centro ls_ctr-centro iu_msgty
                          iu_mensaje iu_docnum.
  ENDLOOP.

  LOOP AT iu_mat-t_almacen INTO DATA(ls_alm).
    lv_any_line = abap_true.
    lv_clave = |{ ls_alm-centro }/{ ls_alm-almacen }|.
    PERFORM add_log USING lv_icon lv_est gc_sheet_almacenes ls_alm-row
                          iu_mat-material gc_nivel_almacen lv_clave iu_msgty
                          iu_mensaje iu_docnum.
  ENDLOOP.

  LOOP AT iu_mat-t_valoracion INTO DATA(ls_val).
    lv_any_line = abap_true.
    PERFORM add_log USING lv_icon lv_est gc_sheet_valoracion ls_val-row
                          iu_mat-material gc_nivel_valoracion ls_val-area_valoracion iu_msgty
                          iu_mensaje iu_docnum.
  ENDLOOP.

  LOOP AT iu_mat-t_ventas INTO DATA(ls_vta).
    lv_any_line = abap_true.
    lv_clave = |{ ls_vta-org_ventas }/{ ls_vta-canal_distrib }|.
    PERFORM add_log USING lv_icon lv_est gc_sheet_ventas ls_vta-row
                          iu_mat-material gc_nivel_ventas lv_clave iu_msgty
                          iu_mensaje iu_docnum.
  ENDLOOP.

  IF lv_any_line = abap_false.
    PERFORM add_log USING lv_icon lv_est gc_sheet_articulos 0
                          iu_mat-material gc_nivel_material space iu_msgty
                          iu_mensaje iu_docnum.
  ENDIF.

ENDFORM.
