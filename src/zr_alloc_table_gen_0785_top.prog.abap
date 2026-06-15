*&---------------------------------------------------------------------*
*& Include          ZR_ALLOC_TABLE_GEN_0785_TOP
*& Pantalla de selección: archivo Excel y modo de ejecución
*&---------------------------------------------------------------------*

SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-001.

PARAMETERS: p_file TYPE string LOWER CASE OBLIGATORY.

SELECTION-SCREEN SKIP.

PARAMETERS: p_sim  RADIOBUTTON GROUP rb1 DEFAULT 'X', " Simulación
            p_real RADIOBUTTON GROUP rb1.             " Ejecución Real

SELECTION-SCREEN END OF BLOCK b01.
