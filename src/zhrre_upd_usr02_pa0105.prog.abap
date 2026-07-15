*----------------------------------------------------------------------
*                 Workbench component Information
*----------------------------------------------------------------------
* Program name          : ZHRRE_UPD_USR02_PA0105
* Functionality         : Actualiza USR02-ACCNT desde PA0105 (SUBTY 0001);
*                          sincroniza PA0105 (SUBTY 0010) con ZSOX_NETUSER
*                          (creando el registro si no existe); y actualiza
*                          USR21-KOSTL con el KOSTL del registro PA0001 con
*                          el AEDTM mas reciente por PERNR
* Functional Consultant: : <Nombre Consultor Funcional>
* Abap Consultant       : <Nombre Consultor ABAP>
* Creation Date         : 2026.07.14
* Ticket                 : ######
*----------------------------------------------------------------------
*                       Modification Log
*----------------------------------------------------------------------
* Description            : Se agrega tercera logica: actualizacion de
*                           USR21-KOSTL desde PA0001
* Functional Consultant: : <Nombre Consultor Funcional>
* Abap Consultant        : <Nombre Consultor ABAP>
* Modification date      : 2026.07.15
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
