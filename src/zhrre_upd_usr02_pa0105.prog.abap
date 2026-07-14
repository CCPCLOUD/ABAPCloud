*----------------------------------------------------------------------
*                 Workbench component Information
*----------------------------------------------------------------------
* Program name          : ZHRRE_UPD_USR02_PA0105
* Functionality         : Actualiza USR02-ACCNT desde PA0105 (SUBTY 0001)
*                          y sincroniza PA0105 (SUBTY 0010) con
*                          ZSOX_NETUSER (creando el registro si no existe)
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
REPORT zhrre_upd_usr02_pa0105.

*----------------------------------------------------------------------
* Includes.
*----------------------------------------------------------------------
INCLUDE zhrre_upd_usr02_pa0105_top.
INCLUDE zhrre_upd_usr02_pa0105_f01.

*----------------------------------------------------------------------
* Start of selection event.
*----------------------------------------------------------------------
START-OF-SELECTION.

  PERFORM main.
