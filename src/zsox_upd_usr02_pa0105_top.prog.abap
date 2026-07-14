*&---------------------------------------------------------------------*
*& Include ZSOX_UPD_USR02_PA0105_TOP
*&---------------------------------------------------------------------*
*& Declaraciones globales (TYPES / DATA)
*&---------------------------------------------------------------------*

TYPES: BEGIN OF ty_usr02_pa0105,
         bname TYPE usr02-bname,
         accnt TYPE usr02-accnt,
         pernr TYPE pa0105-pernr,
       END OF ty_usr02_pa0105.

TYPES: BEGIN OF ty_netuser,
         wikey TYPE zsox_netuser-wikey,
         adid  TYPE zsox_netuser-adid,
       END OF ty_netuser.

DATA: gt_usr02_pa0105 TYPE STANDARD TABLE OF ty_usr02_pa0105,
      gs_usr02_pa0105 TYPE ty_usr02_pa0105,
      gt_netuser      TYPE STANDARD TABLE OF ty_netuser,
      gs_netuser      TYPE ty_netuser,
      gs_pa0105       TYPE pa0105,
      gv_updated_1    TYPE i,
      gv_updated_2    TYPE i,
      gv_created_2    TYPE i,
      gv_errors       TYPE i.
