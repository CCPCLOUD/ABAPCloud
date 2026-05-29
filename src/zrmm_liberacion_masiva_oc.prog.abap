*&---------------------------------------------------------------------*
*& Program: ZRMM_LIBERACION_MASIVA_OC
*& Transaction: ZMM_LIB_OC
*& Description: Liberación masiva de órdenes de compra mediante Excel
*& Specification: P158 - Ticket #26598
*&---------------------------------------------------------------------*
REPORT zrmm_liberacion_masiva_oc.

*----------------------------------------------------------------------*
* TIPOS DE DATOS
*----------------------------------------------------------------------*
TYPES:
  tt_excel TYPE STANDARD TABLE OF alsmex_tabline WITH DEFAULT KEY,

  BEGIN OF ty_excel_raw,
    orden_compra      TYPE c LENGTH 20,
    codigo_liberacion TYPE c LENGTH 10,
  END OF ty_excel_raw,

  BEGIN OF ty_log,
    semaforo          TYPE c LENGTH 1,   " 1=verde, 2=amarillo, 3=rojo
    linea             TYPE numc4,
    ebeln             TYPE ebeln,
    frgco             TYPE frgco,
    bukrs             TYPE bukrs,
    ekorg             TYPE ekorg,
    frgst             TYPE frgst,
    rel_indicator     TYPE c LENGTH 1,
    estatus           TYPE c LENGTH 15,
    mensaje_func      TYPE c LENGTH 80,
    mensaje_sap       TYPE c LENGTH 220,
  END OF ty_log,

  tt_log TYPE STANDARD TABLE OF ty_log WITH DEFAULT KEY.

*----------------------------------------------------------------------*
* CONSTANTES
*----------------------------------------------------------------------*
CONSTANTS:
  gc_verde    TYPE c LENGTH 1 VALUE '1',
  gc_amarillo TYPE c LENGTH 1 VALUE '2',
  gc_rojo     TYPE c LENGTH 1 VALUE '3'.

*----------------------------------------------------------------------*
* PANTALLA DE SELECCIÓN
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
  PARAMETERS:
    p_file TYPE rlgrap-filename OBLIGATORY,
    p_simu TYPE abap_bool AS CHECKBOX DEFAULT abap_false.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN FUNCTION KEY 1.

*----------------------------------------------------------------------*
* VARIABLES GLOBALES
*----------------------------------------------------------------------*
DATA:
  gt_log      TYPE tt_log,
  gt_fieldcat TYPE slis_t_fieldcat_alv,
  gs_layout   TYPE slis_layout_alv.

*----------------------------------------------------------------------*
* AT SELECTION-SCREEN OUTPUT
*----------------------------------------------------------------------*
AT SELECTION-SCREEN OUTPUT.
  %_p_file_%_app_%-text = 'Archivo Excel (.xlsx)'.
  %_p_simu_%_app_%-text = 'Modo simulación (no confirma cambios)'.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.
  CALL FUNCTION 'F4_FILENAME'
    EXPORTING
      program_name  = syst-repid
      dynpro_number = syst-dynnr
      field_name    = 'P_FILE'
    IMPORTING
      file_name     = p_file.

*----------------------------------------------------------------------*
* INICIO DEL PROGRAMA PRINCIPAL
*----------------------------------------------------------------------*
START-OF-SELECTION.
  PERFORM f_validar_archivo.
  PERFORM f_procesar_archivo.
  PERFORM f_mostrar_log.

*----------------------------------------------------------------------*
* FORM: Validar que el archivo tiene extensión xlsx
*----------------------------------------------------------------------*
FORM f_validar_archivo.
  DATA lv_ext TYPE string.
  DATA lv_file TYPE string.

  lv_file = p_file.
  TRANSLATE lv_file TO LOWER CASE.

  IF lv_file NS '.xlsx'.
    MESSAGE 'El archivo debe tener extensión .xlsx' TYPE 'E'.
  ENDIF.
ENDFORM.

*----------------------------------------------------------------------*
* FORM: Leer Excel y procesar registros
*----------------------------------------------------------------------*
FORM f_procesar_archivo.
  DATA:
    lt_excel    TYPE TABLE OF alsmex_tabline,
    ls_excel    TYPE alsmex_tabline,
    lt_raw      TYPE TABLE OF ty_excel_raw,
    ls_raw      TYPE ty_excel_raw,
    ls_log      TYPE ty_log,
    lv_row      TYPE i,
    lv_col      TYPE i,
    lv_orden    TYPE c LENGTH 20,
    lv_codlib   TYPE c LENGTH 10,
    lv_tabix    TYPE i.

  * Leer archivo Excel usando función estándar
  CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
    EXPORTING
      filename                = p_file
      i_begin_col             = 1
      i_begin_row             = 1
      i_end_col               = 2
      i_end_row               = 9999
    TABLES
      intern                  = lt_excel
    EXCEPTIONS
      inconsistent_parameters = 1
      upload_ole              = 2
      OTHERS                  = 3.

  IF sy-subrc <> 0.
    MESSAGE 'Error al leer el archivo Excel. Verifique que no esté abierto.' TYPE 'E'.
  ENDIF.

  IF lt_excel IS INITIAL.
    MESSAGE 'El archivo Excel no contiene datos.' TYPE 'E'.
  ENDIF.

  * Verificar encabezados en fila 1
  PERFORM f_validar_encabezados USING lt_excel.

  * Construir tabla de registros a procesar (desde fila 2)
  LOOP AT lt_excel INTO ls_excel WHERE row >= 2.
    lv_tabix = sy-tabix.
    lv_row = ls_excel-row.
    lv_col = ls_excel-col.

    IF lv_col = 1.
      ls_raw-orden_compra = ls_excel-value.
    ELSEIF lv_col = 2.
      ls_raw-codigo_liberacion = ls_excel-value.
    ENDIF.

    * Verificar si es el último campo de la fila
    READ TABLE lt_excel WITH KEY row = lv_row col = 2 INTO DATA(ls_check).
    IF sy-subrc = 0 AND lv_col = 2.
      APPEND ls_raw TO lt_raw.
      CLEAR ls_raw.
    ENDIF.
  ENDLOOP.

  * Eliminar filas completamente vacías
  DELETE lt_raw WHERE orden_compra IS INITIAL AND codigo_liberacion IS INITIAL.

  IF lt_raw IS INITIAL.
    MESSAGE 'El archivo no contiene registros a procesar (desde fila 2).' TYPE 'E'.
  ENDIF.

  * Procesar cada registro
  LOOP AT lt_raw INTO ls_raw.
    DATA(lv_fila) = sy-tabix + 1.   " +1 porque fila 1 es encabezado
    CLEAR ls_log.
    ls_log-linea = lv_fila.

    * Normalizar orden de compra (ALPHA IN - rellenar con ceros a la izquierda)
    DATA lv_ebeln TYPE ebeln.
    lv_orden = CONV string( ls_raw-orden_compra ).
    CONDENSE lv_orden NO-GAPS.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = ls_raw-orden_compra
      IMPORTING
        output = lv_ebeln.

    DATA lv_frgco TYPE frgco.
    lv_frgco = ls_raw-codigo_liberacion.
    CONDENSE lv_frgco NO-GAPS.
    TRANSLATE lv_frgco TO UPPER CASE.

    ls_log-ebeln = lv_ebeln.
    ls_log-frgco = lv_frgco.

    * Validar campos obligatorios
    IF lv_ebeln IS INITIAL.
      ls_log-semaforo    = gc_rojo.
      ls_log-estatus     = 'Error'.
      ls_log-mensaje_func = 'Número de orden de compra vacío.'.
      APPEND ls_log TO gt_log.
      CONTINUE.
    ENDIF.

    IF lv_frgco IS INITIAL.
      ls_log-semaforo    = gc_rojo.
      ls_log-estatus     = 'Error'.
      ls_log-mensaje_func = 'Código de liberación vacío.'.
      APPEND ls_log TO gt_log.
      CONTINUE.
    ENDIF.

    * Validar existencia de la OC en EKKO
    PERFORM f_validar_oc
      USING    lv_ebeln lv_frgco
      CHANGING ls_log.

    IF ls_log-semaforo = gc_rojo.
      APPEND ls_log TO gt_log.
      CONTINUE.
    ENDIF.

    * Ejecutar liberación si no es simulación
    IF p_simu = abap_false.
      PERFORM f_ejecutar_bapi
        USING    lv_ebeln lv_frgco
        CHANGING ls_log.
    ELSE.
      ls_log-semaforo     = gc_amarillo.
      ls_log-estatus      = 'Simulado'.
      ls_log-mensaje_func = 'Registro válido. Simulación: no se ejecutaron cambios.'.
    ENDIF.

    APPEND ls_log TO gt_log.
  ENDLOOP.
ENDFORM.

*----------------------------------------------------------------------*
* FORM: Validar encabezados del Excel
*----------------------------------------------------------------------*
FORM f_validar_encabezados USING pt_excel TYPE tt_excel.
  DATA ls_line TYPE alsmex_tabline.
  DATA lv_col1 TYPE string.
  DATA lv_col2 TYPE string.

  READ TABLE pt_excel INTO ls_line WITH KEY row = 1 col = 1.
  IF sy-subrc = 0.
    lv_col1 = ls_line-value.
    TRANSLATE lv_col1 TO UPPER CASE.
    CONDENSE lv_col1 NO-GAPS.
  ENDIF.

  READ TABLE pt_excel INTO ls_line WITH KEY row = 1 col = 2.
  IF sy-subrc = 0.
    lv_col2 = ls_line-value.
    TRANSLATE lv_col2 TO UPPER CASE.
    CONDENSE lv_col2 NO-GAPS.
  ENDIF.

  IF lv_col1 <> 'ORDEN_COMPRA'.
    MESSAGE |Columna A debe llamarse ORDEN_COMPRA. Encontrado: { lv_col1 }| TYPE 'E'.
  ENDIF.

  IF lv_col2 <> 'CODIGO_LIBERACION'.
    MESSAGE |Columna B debe llamarse CODIGO_LIBERACION. Encontrado: { lv_col2 }| TYPE 'E'.
  ENDIF.
ENDFORM.

*----------------------------------------------------------------------*
* FORM: Validar existencia y estatus de la OC
*----------------------------------------------------------------------*
FORM f_validar_oc
  USING    pv_ebeln TYPE ebeln
           pv_frgco TYPE frgco
  CHANGING ps_log   TYPE ty_log.

  DATA ls_ekko TYPE ekko.

  * Verificar existencia en EKKO
  SELECT SINGLE *
    FROM ekko
    INTO @ls_ekko
    WHERE ebeln = @pv_ebeln
      AND loekz = @space.

  IF sy-subrc <> 0.
    ps_log-semaforo     = gc_rojo.
    ps_log-estatus      = 'Error'.
    ps_log-mensaje_func = |OC { pv_ebeln } no existe o está borrada.|.
    RETURN.
  ENDIF.

  ps_log-bukrs = ls_ekko-bukrs.
  ps_log-ekorg = ls_ekko-ekorg.
  ps_log-frgst = ls_ekko-frgst.

  * Verificar que la OC no esté completamente liberada
  IF ls_ekko-frgst = ls_ekko-frgke.
    ps_log-semaforo     = gc_amarillo.
    ps_log-estatus      = 'Advertencia'.
    ps_log-mensaje_func = |OC { pv_ebeln } ya se encuentra completamente liberada.|.
    RETURN.
  ENDIF.

  * Verificar que el código de liberación exista en la estrategia de la OC (T16FK)
  SELECT SINGLE frgco
    FROM t16fk
    INTO @DATA(lv_frgco_check)
    WHERE frgsx = @ls_ekko-frgsx
      AND frgco = @pv_frgco.

  IF sy-subrc <> 0.
    ps_log-semaforo     = gc_rojo.
    ps_log-estatus      = 'Error'.
    ps_log-mensaje_func = |Código liberador { pv_frgco } no corresponde a la estrategia de la OC.|.
    RETURN.
  ENDIF.

  * Si llegamos aquí, la OC es válida para intentar liberación
  ps_log-semaforo = gc_verde.
ENDFORM.

*----------------------------------------------------------------------*
* FORM: Llamar BAPI_PO_RELEASE y registrar resultado
*----------------------------------------------------------------------*
FORM f_ejecutar_bapi
  USING    pv_ebeln TYPE ebeln
           pv_frgco TYPE frgco
  CHANGING ps_log   TYPE ty_log.

  DATA:
    lv_rel_status    TYPE bapimepoheader-rel_status,
    lv_rel_indicator TYPE bapimepoheader-rel_indicator,
    lt_return        TYPE TABLE OF bapiret2,
    ls_return        TYPE bapiret2,
    lv_hay_error     TYPE abap_bool VALUE abap_false,
    lv_mensaje       TYPE string.

  CALL FUNCTION 'BAPI_PO_RELEASE'
    EXPORTING
      purchaseorder  = pv_ebeln
      po_rel_code    = pv_frgco
    IMPORTING
      rel_status     = lv_rel_status
      rel_indicator  = lv_rel_indicator
    TABLES
      return         = lt_return.

  ps_log-rel_indicator = lv_rel_indicator.
  ps_log-frgst         = lv_rel_status.

  * Analizar mensajes de retorno
  LOOP AT lt_return INTO ls_return.
    IF ls_return-type = 'E' OR ls_return-type = 'A'.
      lv_hay_error = abap_true.
    ENDIF.
    IF lv_mensaje IS INITIAL.
      lv_mensaje = |{ ls_return-type } { ls_return-id } { ls_return-number }: { ls_return-message }|.
    ELSE.
      lv_mensaje = |{ lv_mensaje } / { ls_return-type } { ls_return-id } { ls_return-number }: { ls_return-message }|.
    ENDIF.
  ENDLOOP.

  ps_log-mensaje_sap = lv_mensaje.

  IF lv_hay_error = abap_false AND lv_rel_indicator = 'V'.
    * Liberación exitosa - confirmar
    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
      EXPORTING
        wait = abap_true.

    ps_log-semaforo     = gc_verde.
    ps_log-estatus      = 'Éxito'.
    ps_log-mensaje_func = |OC { pv_ebeln } liberada correctamente con código { pv_frgco }.|.

  ELSEIF lv_hay_error = abap_false AND lv_rel_indicator <> 'V'.
    * BAPI ejecutada sin error pero liberación parcial (más niveles pendientes)
    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
      EXPORTING
        wait = abap_true.

    ps_log-semaforo     = gc_verde.
    ps_log-estatus      = 'Éxito'.
    ps_log-mensaje_func = |Nivel { pv_frgco } liberado. OC { pv_ebeln } pendiente de niveles superiores.|.

  ELSE.
    * Error en BAPI - revertir
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.

    ps_log-semaforo     = gc_rojo.
    ps_log-estatus      = 'Error'.
    IF ps_log-mensaje_func IS INITIAL.
      ps_log-mensaje_func = |Error al liberar OC { pv_ebeln } con código { pv_frgco }.|.
    ENDIF.
  ENDIF.
ENDFORM.

*----------------------------------------------------------------------*
* FORM: Mostrar log ALV con semáforo
*----------------------------------------------------------------------*
FORM f_mostrar_log.
  DATA:
    lt_fieldcat TYPE slis_t_fieldcat_alv,
    ls_fieldcat TYPE slis_fieldcat_alv,
    ls_layout   TYPE slis_layout_alv,
    ls_event    TYPE slis_alv_event,
    lt_events   TYPE slis_t_event,
    lv_correctos  TYPE i,
    lv_errores    TYPE i,
    lv_simulados  TYPE i,
    lv_procesados TYPE i.

  * Calcular totales
  LOOP AT gt_log INTO DATA(ls_log_total).
    lv_procesados = lv_procesados + 1.
    CASE ls_log_total-semaforo.
      WHEN gc_verde.    lv_correctos  = lv_correctos  + 1.
      WHEN gc_rojo.     lv_errores    = lv_errores    + 1.
      WHEN gc_amarillo. lv_simulados  = lv_simulados  + 1.
    ENDCASE.
  ENDLOOP.

  * Layout ALV
  ls_layout-colwidth_optimize = abap_true.
  ls_layout-zebra             = abap_true.
  ls_layout-info_fieldname    = 'SEMAFORO'.
  ls_layout-lights_fieldname  = 'SEMAFORO'.
  ls_layout-box_tabname       = 'GT_LOG'.

  * Definición de columnas
  DEFINE add_field.
    CLEAR ls_fieldcat.
    ls_fieldcat-fieldname   = &1.
    ls_fieldcat-tabname     = 'GT_LOG'.
    ls_fieldcat-seltext_m   = &2.
    ls_fieldcat-outputlen   = &3.
    ls_fieldcat-just        = &4.
    APPEND ls_fieldcat TO lt_fieldcat.
  END-OF-DEFINITION.

  add_field 'SEMAFORO'      'Sem.'              4  'C'.
  add_field 'LINEA'         'Fila'              5  'R'.
  add_field 'EBELN'         'Orden de compra'  12  'L'.
  add_field 'FRGCO'         'Cód. liberación'   6  'C'.
  add_field 'BUKRS'         'Sociedad'          6  'C'.
  add_field 'EKORG'         'Org. compras'      8  'C'.
  add_field 'FRGST'         'Estrategia'        8  'C'.
  add_field 'REL_INDICATOR' 'Ind. lib.'         5  'C'.
  add_field 'ESTATUS'       'Estatus'          15  'L'.
  add_field 'MENSAJE_FUNC'  'Mensaje funcional' 80 'L'.
  add_field 'MENSAJE_SAP'   'Mensaje SAP/BAPI' 220 'L'.

  * Evento para pie de página con totales
  ls_event-name    = slis_ev_end_of_list.
  ls_event-form    = 'F_ALV_FOOTER'.
  APPEND ls_event TO lt_events.

  * Pasar totales a través de variables globales (usadas en footer)
  SET PARAMETER ID 'ZMM_PROC' FIELD lv_procesados.
  SET PARAMETER ID 'ZMM_OK'   FIELD lv_correctos.
  SET PARAMETER ID 'ZMM_ERR'  FIELD lv_errores.
  SET PARAMETER ID 'ZMM_SIM'  FIELD lv_simulados.

  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
    EXPORTING
      i_callback_program = sy-repid
      it_fieldcat        = lt_fieldcat
      is_layout          = ls_layout
      it_events          = lt_events
      i_save             = 'A'
    TABLES
      t_outtab           = gt_log
    EXCEPTIONS
      program_error      = 1
      OTHERS             = 2.
ENDFORM.

*----------------------------------------------------------------------*
* FORM: Footer ALV con totales
*----------------------------------------------------------------------*
FORM f_alv_footer USING pt_list_commentary TYPE slis_t_listheader
                        pa_ausgabe_info    TYPE char8.
  DATA:
    ls_line      TYPE slis_listheader,
    lv_procesados TYPE i,
    lv_correctos  TYPE i,
    lv_errores    TYPE i,
    lv_simulados  TYPE i.

  GET PARAMETER ID 'ZMM_PROC' FIELD lv_procesados.
  GET PARAMETER ID 'ZMM_OK'   FIELD lv_correctos.
  GET PARAMETER ID 'ZMM_ERR'  FIELD lv_errores.
  GET PARAMETER ID 'ZMM_SIM'  FIELD lv_simulados.

  ls_line-typ  = 'S'.
  ls_line-key  = 'Procesados:'.
  ls_line-info = |{ lv_procesados } | &
                 |Correctos: { lv_correctos } | &
                 |Errores: { lv_errores } | &
                 |Simulados/Advertencias: { lv_simulados }|.
  APPEND ls_line TO pt_list_commentary.
ENDFORM.
