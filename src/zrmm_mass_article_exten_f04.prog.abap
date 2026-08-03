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
                    iu_idoc_no  TYPE edi_docnum.

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
*&
*&  Se usa CL_SALV_TABLE en lugar de REUSE_ALV_GRID_DISPLAY porque este
*&  ultimo requiere una estructura registrada en el Diccionario ABAP
*&  (SE11) para construir el catalogo de campos; GTY_S_LOG es un tipo
*&  local del programa, no una estructura DDIC, y CL_SALV_TABLE si
*&  puede construir el catalogo en tiempo de ejecucion a partir de la
*&  tabla interna.
*&---------------------------------------------------------------------*
FORM display_log.

  DATA: lo_salv    TYPE REF TO cl_salv_table,
        lo_columns TYPE REF TO cl_salv_columns_table,
        lo_column  TYPE REF TO cl_salv_column,
        lv_titulo  TYPE string.

  IF git_log IS INITIAL.
    APPEND VALUE gty_s_log( icon = icon_information estatus = 'Información' msgty = 'S'
                             mensaje = 'No se encontraron registros para procesar en el archivo.' )
      TO git_log.
  ENDIF.

  TRY.
      cl_salv_table=>factory(
        IMPORTING
          r_salv_table = lo_salv
        CHANGING
          t_table      = git_log ).
    CATCH cx_salv_msg INTO DATA(lx_salv).
      WRITE: / lx_salv->get_text( ).
      RETURN.
  ENDTRY.

  lo_salv->get_functions( )->set_all( abap_true ).

  lo_columns = lo_salv->get_columns( ).
  lo_columns->set_optimize( abap_true ).

  TRY.
      lo_column = lo_columns->get_column( 'ICON' ).
      lo_column->set_short_text( 'Estatus' ).
      lo_column->set_medium_text( 'Estatus' ).
      lo_column->set_long_text( 'Estatus' ).
      CAST cl_salv_column_table( lo_column )->set_icon( if_salv_c_bool_sap=>true ).

      lo_column = lo_columns->get_column( 'ESTATUS' ).
      lo_column->set_short_text( 'Estado' ).
      lo_column->set_medium_text( 'Estado' ).
      lo_column->set_long_text( 'Descripción' ).

      lo_column = lo_columns->get_column( 'HOJA' ).
      lo_column->set_short_text( 'Hoja' ).
      lo_column->set_medium_text( 'Hoja' ).
      lo_column->set_long_text( 'Hoja' ).

      lo_column = lo_columns->get_column( 'LINEA' ).
      lo_column->set_short_text( 'Línea' ).
      lo_column->set_medium_text( 'Línea' ).
      lo_column->set_long_text( 'Línea' ).

      lo_column = lo_columns->get_column( 'MATERIAL' ).
      lo_column->set_short_text( 'Material' ).
      lo_column->set_medium_text( 'Material' ).
      lo_column->set_long_text( 'Material' ).

      lo_column = lo_columns->get_column( 'NIVEL' ).
      lo_column->set_short_text( 'Nivel' ).
      lo_column->set_medium_text( 'Nivel' ).
      lo_column->set_long_text( 'Nivel' ).

      lo_column = lo_columns->get_column( 'CLAVE_ORG' ).
      lo_column->set_short_text( 'Clave org' ).
      lo_column->set_medium_text( 'Clave organizativa' ).
      lo_column->set_long_text( 'Clave organizativa' ).

      lo_column = lo_columns->get_column( 'IDOC_NO' ).
      lo_column->set_short_text( 'IDoc No.' ).
      lo_column->set_medium_text( 'IDoc No.' ).
      lo_column->set_long_text( 'IDoc No.' ).

      lo_column = lo_columns->get_column( 'MSGTY' ).
      lo_column->set_short_text( 'MsgT' ).
      lo_column->set_medium_text( 'MsgT' ).
      lo_column->set_long_text( 'MsgT' ).

      lo_column = lo_columns->get_column( 'MENSAJE' ).
      lo_column->set_short_text( 'Mensaje' ).
      lo_column->set_medium_text( 'Mensaje' ).
      lo_column->set_long_text( 'Mensaje' ).
    CATCH cx_salv_not_found.
  ENDTRY.

  lv_titulo = |ZMM_ARTICLE_EXTEND - Log de Ampliación Masiva de Artículos  -  |
           && |Procesados { gv_count_total }  |
           && |Éxitos { gv_count_ok }  |
           && |Errores { gv_count_error }  |
           && |Advertencias { gv_count_warn }|.
  lo_salv->get_display_settings( )->set_list_header( lv_titulo ).

  lo_salv->display( ).

ENDFORM.
