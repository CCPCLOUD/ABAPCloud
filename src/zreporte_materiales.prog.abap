*&---------------------------------------------------------------------*
*& Report ZREPORTE_MATERIALES
*& Reporte de materiales con texto en español
*&---------------------------------------------------------------------*
REPORT zreporte_materiales
  LINE-SIZE 132
  LINE-COUNT 65
  MESSAGE-ID 00.

*----------------------------------------------------------------------*
* Tablas de base de datos
*----------------------------------------------------------------------*
TABLES: mara,
        makt.

*----------------------------------------------------------------------*
* Tipos internos
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_material,
         matnr TYPE mara-matnr,
         maktx TYPE makt-maktx,
         mtart TYPE mara-mtart,
         meins TYPE mara-meins,
         ersda TYPE mara-ersda,
       END OF ty_material.

*----------------------------------------------------------------------*
* Variables internas
*----------------------------------------------------------------------*
DATA: gt_material TYPE STANDARD TABLE OF ty_material,
      gs_material TYPE ty_material,
      gv_lines    TYPE i.

*----------------------------------------------------------------------*
* Pantalla de selección
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE text-001.
SELECT-OPTIONS: so_mtart FOR mara-mtart.
SELECTION-SCREEN END OF BLOCK b1.

*----------------------------------------------------------------------*
* Inicialización de textos de pantalla de selección
*----------------------------------------------------------------------*
INITIALIZATION.
  text-001 = 'Criterios de Selección'.

*----------------------------------------------------------------------*
* Evento START-OF-SELECTION
*----------------------------------------------------------------------*
START-OF-SELECTION.
  PERFORM f_select_data.
  PERFORM f_check_data.

*----------------------------------------------------------------------*
* Evento END-OF-SELECTION
*----------------------------------------------------------------------*
END-OF-SELECTION.
  PERFORM f_write_report.

*----------------------------------------------------------------------*
* Subrutinas
*----------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Form F_SELECT_DATA
*&---------------------------------------------------------------------*
FORM f_select_data.

  SELECT a~matnr
         t~maktx
         a~mtart
         a~meins
         a~ersda
    INTO TABLE gt_material
    FROM mara AS a
    INNER JOIN makt AS t
      ON a~matnr = t~matnr
   WHERE a~mtart IN so_mtart
     AND t~spras = 'S'.

  IF sy-subrc <> 0.
    CLEAR gt_material.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form F_CHECK_DATA
*&---------------------------------------------------------------------*
FORM f_check_data.

  DESCRIBE TABLE gt_material LINES gv_lines.

  IF gv_lines = 0.
    MESSAGE 'No se encontraron materiales para los criterios indicados.'
            TYPE 'I'.
    LEAVE LIST-PROCESSING.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form F_WRITE_REPORT
*&---------------------------------------------------------------------*
FORM f_write_report.

  PERFORM f_write_header.

  LOOP AT gt_material INTO gs_material.
    WRITE: /1  gs_material-matnr    NO-ZERO,
            25 gs_material-maktx,
            65 gs_material-mtart,
            75 gs_material-meins,
            85 gs_material-ersda.
  ENDLOOP.

  SKIP.
  WRITE: / 'Total de registros:', gv_lines.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form F_WRITE_HEADER
*&---------------------------------------------------------------------*
FORM f_write_header.

  WRITE: /1   'Número de Material',
          25  'Descripción',
          65  'Tipo Mat.',
          75  'UM Base',
          85  'Fecha Creación'.

  ULINE AT /1(105).

ENDFORM.

*----------------------------------------------------------------------*
* Evento TOP-OF-PAGE
*----------------------------------------------------------------------*
TOP-OF-PAGE.

  WRITE: /1 'Reporte de Materiales'(002).
  WRITE: 90 'Fecha:'(003), sy-datum, 'Hora:'(004), sy-uzeit.
  WRITE: /1 'Sociedad/Mandante:'(005), sy-mandt.
  ULINE AT /1(132).
  SKIP.

  PERFORM f_write_header.
