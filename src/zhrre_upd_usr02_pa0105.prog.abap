*----------------------------------------------------------------------
*                 Workbench component Information
*----------------------------------------------------------------------
* Program name          : ZHRRE_UPD_USR02_PA0105
* Functionality         : Updates USR02-ACCNT from PA0105 (SUBTY 0001);
*                          syncs PA0105 (SUBTY 0010) with ZSOX_NETUSER
*                          (creating the record if it does not exist); and
*                          updates USR21-KOSTL with the KOSTL of the PA0001
*                          record with the latest AEDTM per PERNR
* Functional Consultant: : <Functional Consultant Name>
* Abap Consultant       : <ABAP Consultant Name>
* Creation Date         : 2026.07.14
* Ticket                 : ######
*----------------------------------------------------------------------
*                       Modification Log
*----------------------------------------------------------------------
* Description            : Added third logic: update USR21-KOSTL from
*                           PA0001
* Functional Consultant: : <Functional Consultant Name>
* Abap Consultant        : <ABAP Consultant Name>
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
