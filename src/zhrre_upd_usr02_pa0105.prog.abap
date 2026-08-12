*----------------------------------------------------------------------
*                 Workbench component Information
*----------------------------------------------------------------------
* Program name          : ZHRRE_UPD_USR02_PA0105
* Functionality         : For each USR02 (USTYP = 'A') joined to PA0002
*                          via USR02-ACCNT = PA0002-PERNR: updates
*                          ADR6-SMTP_ADDR from PA0105-USRID_LONG (SUBTY
*                          0010, via BAPI_USER_CHANGE), USR21-KOSTL from
*                          the PA0001 record with the latest AEDTM, and
*                          PA0105-USRID (SUBTY 0010) from USR02-BNAME
* Functional Consultant: : <Functional Consultant Name>
* Abap Consultant       : <ABAP Consultant Name>
* Creation Date         : 2026.07.14
* Ticket                 : ######
*----------------------------------------------------------------------
*                       Modification Log
*----------------------------------------------------------------------
* Description            : Replaced logic per updated requirements: base
*                           selection is now USR02 (USTYP = 'A') joined
*                           to PA0002, driving updates to ADR6-SMTP_ADDR,
*                           USR21-KOSTL and PA0105-USRID
* Functional Consultant: : <Functional Consultant Name>
* Abap Consultant        : <ABAP Consultant Name>
* Modification date      : 2026.08.12
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
