*----------------------------------------------------------------------
*                    Report List Information
*----------------------------------------------------------------------
* Program name          : ZHRRE_UPD_USR02_PA0105
* Include name           : ZHRRE_UPD_USR02_PA0105_TOP
* Functionality         : Global declarations (TYPES / DATA)
* Functional Consultant: : <Functional Consultant Name>
* Abap Consultant       : <ABAP Consultant Name>
* Creation Date         : 2026.07.14
* Ticket                 : ######
*----------------------------------------------------------------------
*                       Modification Log
*----------------------------------------------------------------------
* Description            : Replaced logic: base selection is now
*                           USR02 (USTYP = 'A') joined to PA0002, driving
*                           updates to ADR6-SMTP_ADDR, USR21-KOSTL and
*                           PA0105-USRID
* Functional Consultant: : <Functional Consultant Name>
* Abap Consultant        : <ABAP Consultant Name>
* Modification date      : 2026.08.12
* Ticket                 : ######
*----------------------------------------------------------------------

*----------------------------------------------------------------------
* Types
*----------------------------------------------------------------------
TYPES: BEGIN OF ty_usr02_a,
         bname TYPE usr02-bname,
         accnt TYPE usr02-accnt,
         pernr TYPE pa0002-pernr,
       END OF ty_usr02_a.

TYPES: BEGIN OF ty_base,
         bname      TYPE usr02-bname,
         pernr      TYPE pa0002-pernr,
         addrnumber TYPE usr21-addrnumber,
         persnumber TYPE usr21-persnumber,
         objps      TYPE pa0105-objps,
         sprps      TYPE pa0105-sprps,
         begda      TYPE pa0105-begda,
         endda      TYPE pa0105-endda,
         usrid_long TYPE pa0105-usrid_long,
         kostl      TYPE pa0001-kostl,
       END OF ty_base.

TYPES: BEGIN OF ty_pa0001_kostl,
         pernr TYPE pa0001-pernr,
         kostl TYPE pa0001-kostl,
         aedtm TYPE pa0001-aedtm,
       END OF ty_pa0001_kostl.

*----------------------------------------------------------------------
* Internal tables / Structures / Variables
*----------------------------------------------------------------------
DATA: gt_base          TYPE STANDARD TABLE OF ty_base,
      gs_base          TYPE ty_base,
      gv_updated_adr6  TYPE i,
      gv_updated_kostl TYPE i,
      gv_updated_usrid TYPE i,
      gv_errors        TYPE i.
