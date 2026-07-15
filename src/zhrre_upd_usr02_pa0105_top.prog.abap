*----------------------------------------------------------------------
*                    Report List Information
*----------------------------------------------------------------------
* Program name          : ZHRRE_UPD_USR02_PA0105
* Include name           : ZHRRE_UPD_USR02_PA0105_TOP
* Functionality         : Declaraciones globales (TYPES / DATA)
* Functional Consultant: : <Nombre Consultor Funcional>
* Abap Consultant       : <Nombre Consultor ABAP>
* Creation Date         : 2026.07.14
* Ticket                 : ######
*----------------------------------------------------------------------
*                       Modification Log
*----------------------------------------------------------------------
* Description            : <Objetivo del cambio>
* Functional Consultant: : <Nombre Consultor Funcional>
* Abap Consultant        : <Nombre Consultor ABAP>
* Modification date      : YYYY.MM.DD
* Ticket                 : ######
*----------------------------------------------------------------------

*----------------------------------------------------------------------
* Types
*----------------------------------------------------------------------
TYPES: BEGIN OF ty_usr02_pa0105,
         bname TYPE usr02-bname,
         accnt TYPE usr02-accnt,
         pernr TYPE pa0105-pernr,
       END OF ty_usr02_pa0105.

TYPES: BEGIN OF ty_netuser,
         wikey TYPE zsox_netuser-wikey,
         adid  TYPE zsox_netuser-adid,
       END OF ty_netuser.

TYPES: BEGIN OF ty_usr21,
         bname      TYPE usr21-bname,
         persnumber TYPE usr21-persnumber,
         kostl      TYPE usr21-kostl,
         pernr      TYPE pa0001-pernr,
       END OF ty_usr21.

TYPES: BEGIN OF ty_pa0001_kostl,
         pernr TYPE pa0001-pernr,
         kostl TYPE pa0001-kostl,
         aedtm TYPE pa0001-aedtm,
       END OF ty_pa0001_kostl.

*----------------------------------------------------------------------
* Internal tables / Structures / Variables
*----------------------------------------------------------------------
DATA: gt_usr02_pa0105 TYPE STANDARD TABLE OF ty_usr02_pa0105,
      gs_usr02_pa0105 TYPE ty_usr02_pa0105,
      gt_netuser      TYPE STANDARD TABLE OF ty_netuser,
      gs_netuser      TYPE ty_netuser,
      gs_pa0105       TYPE pa0105,
      gt_usr21        TYPE STANDARD TABLE OF ty_usr21,
      gs_usr21        TYPE ty_usr21,
      gt_pa0001_kostl TYPE STANDARD TABLE OF ty_pa0001_kostl,
      gs_pa0001_kostl TYPE ty_pa0001_kostl,
      gv_updated_1    TYPE i,
      gv_updated_2    TYPE i,
      gv_created_2    TYPE i,
      gv_updated_3    TYPE i,
      gv_errors       TYPE i.
