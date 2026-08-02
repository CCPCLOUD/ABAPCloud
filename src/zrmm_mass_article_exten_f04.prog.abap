*&---------------------------------------------------------------------*
*& Include ZRMM_MASS_ARTICLE_EXTEN_F04
*& Log de resultados (FS 2.4.8) y presentacion ALV (FS 2.4.5 - Ejemplo
*& de Layout ALV)
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*&      Form  ADD_LOG
*&  Agrega una linea al log de resultados y actualiza los contadores
*&---------------------------------------------------------------------*
FORM add_log USING iu_icon      TYPE icon_d
                    iu_estatus  TYPE any
                    iu_hoja     TYPE any
                    iu_linea    TYPE i
                    iu_material TYPE any
                    iu_nivel    TYPE any
                    iu_clave    TYPE any
                    iu_msgty    TYPE any
                    iu_mensaje  TYPE any
                    iu_idoc_no  TYPE edi_docnum DEFAULT '0000000000000000'.

  DATA: ls_log TYPE gty_s_log.

  ls_log-icon      = iu_icon.
  ls_log-estatus   = iu_estatus.
  ls_log-hoja      = iu_hoja.
  ls_log-linea     = iu_linea.
  ls_log-material  = iu_material.
  ls_log-nivel     = iu_nivel.
  ls_log-clave_org = iu_clave.
  ls_log-msgty     = iu_msgty.
  ls_log-mensaje   = iu_mensaje.
  ls_log-idoc_no   = iu_idoc_no.

  APPEND ls_log TO git_log.

  gv_count_total = gv_count_total + 1.
  CASE iu_msgty.
    WHEN 'S'.
      gv_count_ok    = gv_count_ok + 1.
    WHEN 'E'.
      gv_count_error = gv_count_error + 1.
    WHEN 'W'.
      gv_count_warn  = gv_count_warn + 1.
  ENDCASE.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  DISPLAY_LOG
*&  Muestra el log en un grid ALV (columnas segun FS 2.4.5)
*&---------------------------------------------------------------------*
FORM display_log.

  DATA: lt_fcat TYPE slis_t_fieldcat_alv,
        ls_lout TYPE slis_layout_alv.

  IF git_log IS INITIAL.
    APPEND VALUE gty_s_log( icon = icon_information estatus = 'Información' msgty = 'S'
                             mensaje = 'No se encontraron registros para procesar en el archivo.' )
      TO git_log.
  ENDIF.

  CALL FUNCTION 'REUSE_ALV_FIELDCATALOG_MERGE'
    EXPORTING
      i_structure_name = 'GTY_S_LOG'
    CHANGING
      ct_fieldcat      = lt_fcat
    EXCEPTIONS
      OTHERS           = 1.

  LOOP AT lt_fcat ASSIGNING FIELD-SYMBOL(<ls_fcat>).
    CASE <ls_fcat>-fieldname.
      WHEN 'ICON'.
        <ls_fcat>-seltext_l   = 'Estatus'.
        <ls_fcat>-icon        = abap_true.
        <ls_fcat>-outputlen   = 6.
      WHEN 'ESTATUS'.
        <ls_fcat>-seltext_l   = 'Descripción'.
      WHEN 'HOJA'.
        <ls_fcat>-seltext_l   = 'Hoja'.
      WHEN 'LINEA'.
        <ls_fcat>-seltext_l   = 'Línea'.
      WHEN 'MATERIAL'.
        <ls_fcat>-seltext_l   = 'Material'.
      WHEN 'NIVEL'.
        <ls_fcat>-seltext_l   = 'Nivel'.
      WHEN 'CLAVE_ORG'.
        <ls_fcat>-seltext_l   = 'Clave organizativa'.
      WHEN 'IDOC_NO'.
        <ls_fcat>-seltext_l   = 'IDoc No.'.
      WHEN 'MSGTY'.
        <ls_fcat>-seltext_l   = 'MsgT'.
      WHEN 'MENSAJE'.
        <ls_fcat>-seltext_l   = 'Mensaje'.
        <ls_fcat>-outputlen   = 80.
    ENDCASE.
  ENDLOOP.

  ls_lout-zebra            = abap_true.
  ls_lout-colwidth_optimize = abap_true.

  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
    EXPORTING
      i_callback_program = sy-repid
      i_callback_top_of_page = 'TOP_OF_PAGE_LOG'
      is_layout           = ls_lout
      it_fieldcat          = lt_fcat
      i_save               = 'A'
    TABLES
      t_outtab             = git_log
    EXCEPTIONS
      OTHERS               = 1.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  TOP_OF_PAGE_LOG
*&  Totales del procesamiento (FS 2.4.5 - fila "Totales")
*&---------------------------------------------------------------------*
FORM top_of_page_log.

  DATA: lt_line TYPE slis_t_listheader,
        ls_line TYPE slis_listheader.

  ls_line-typ  = 'H'.
  ls_line-info = 'ZMM_ARTICLE_EXTEND - Log de Ampliación Masiva de Artículos'.
  APPEND ls_line TO lt_line.

  ls_line-typ  = 'S'.
  ls_line-key  = 'Totales:'.
  ls_line-info = |Procesados { gv_count_total }  |
              && |Éxitos { gv_count_ok }  |
              && |Errores { gv_count_error }  |
              && |Advertencias { gv_count_warn }|.
  APPEND ls_line TO lt_line.

  CALL FUNCTION 'REUSE_ALV_COMMENTARY_WRITE'
    EXPORTING
      it_list_commentary = lt_line.

ENDFORM.
