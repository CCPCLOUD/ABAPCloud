*----------------------------------------------------------------------
*                    Report List Information
*----------------------------------------------------------------------
* Program name          : ZHRRE_UPD_USR02_PA0105
* Include name           : ZHRRE_UPD_USR02_PA0105_F01
* Functionality         : Program FORM routines
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

*&---------------------------------------------------------------------*
*&      Form  MAIN
*&---------------------------------------------------------------------*
FORM main.

* Step 1-2: USR02 (USTYP = 'A') joined to PA0002, dropping blank ACCNT
  PERFORM build_base_selection.

* Step 3: USR21-ADDRNUMBER / USR21-PERSNUMBER via USR02-BNAME
  PERFORM enrich_usr21_address.

* Step 4: PA0105-USRID_LONG (SUBTY 0010, record valid today) via PERNR
  PERFORM enrich_pa0105_email.

* Step 5: ADR6-SMTP_ADDR <- PA0105-USRID_LONG
  PERFORM update_adr6_smtp.

* Step 6: PA0001-KOSTL (record with the latest AEDTM) via PERNR
  PERFORM enrich_pa0001_kostl.

* Step 7: USR21-KOSTL <- PA0001-KOSTL
  PERFORM update_usr21_kostl.

* Step 8: PA0105-USRID <- USR02-BNAME (SUBTY 0010)
  PERFORM update_pa0105_usrid.

* Show the results summary
  PERFORM display_results.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  BUILD_BASE_SELECTION
*&---------------------------------------------------------------------*
*&  GT_BASE (BNAME, PERNR): USR02 (USTYP = 'A'), USR02-ACCNT not blank,
*&  PA0002-PERNR = USR02-ACCNT
*&---------------------------------------------------------------------*
FORM build_base_selection.

  DATA: lt_usr02     TYPE STANDARD TABLE OF ty_usr02_a,
        ls_usr02     TYPE ty_usr02_a,
        lt_usr02_cpy TYPE STANDARD TABLE OF ty_usr02_a,
        lt_pa0002    TYPE STANDARD TABLE OF pa0002-pernr.

  REFRESH gt_base.

  SELECT bname accnt
    INTO CORRESPONDING FIELDS OF TABLE lt_usr02
    FROM usr02
    WHERE ustyp = 'A'.

* Drop records where USR02-ACCNT is blank or not numeric (can't map to
* a PERNR), then convert ACCNT to PA0002-PERNR format (a plain MOVE
* performs the implicit CHAR -> NUMC zero-padding)
  LOOP AT lt_usr02 INTO ls_usr02.
    IF ls_usr02-accnt IS INITIAL OR ls_usr02-accnt NOT CO '0123456789 '.
      DELETE lt_usr02.
    ELSE.
      ls_usr02-pernr = ls_usr02-accnt.
      MODIFY lt_usr02 FROM ls_usr02 TRANSPORTING pernr.
    ENDIF.
  ENDLOOP.

  CHECK lt_usr02 IS NOT INITIAL.

* Copy without duplicates to check which PERNR actually exist in PA0002
  lt_usr02_cpy[] = lt_usr02.
  SORT lt_usr02_cpy BY pernr.
  DELETE ADJACENT DUPLICATES FROM lt_usr02_cpy COMPARING pernr.

  SELECT pernr
    INTO TABLE lt_pa0002
    FROM pa0002
    FOR ALL ENTRIES IN lt_usr02_cpy
    WHERE pernr = lt_usr02_cpy-pernr.

  SORT lt_pa0002.
  DELETE ADJACENT DUPLICATES FROM lt_pa0002.

* Keep only USR02 rows whose PERNR actually exists in PA0002
  LOOP AT lt_usr02 INTO ls_usr02.
    READ TABLE lt_pa0002 TRANSPORTING NO FIELDS
      WITH KEY table_line = ls_usr02-pernr BINARY SEARCH.
    CHECK sy-subrc = 0.

    CLEAR gs_base.
    gs_base-bname = ls_usr02-bname.
    gs_base-pernr = ls_usr02-pernr.
    APPEND gs_base TO gt_base.
  ENDLOOP.

  SORT gt_base BY bname.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  ENRICH_USR21_ADDRESS
*&---------------------------------------------------------------------*
*&  GT_BASE-ADDRNUMBER / GT_BASE-PERSNUMBER <- USR21, via USR02-BNAME
*&---------------------------------------------------------------------*
FORM enrich_usr21_address.

  TYPES: BEGIN OF ty_usr21_addr,
           bname      TYPE usr21-bname,
           addrnumber TYPE usr21-addrnumber,
           persnumber TYPE usr21-persnumber,
         END OF ty_usr21_addr.

  DATA: lt_usr21 TYPE STANDARD TABLE OF ty_usr21_addr,
        ls_usr21 TYPE ty_usr21_addr.

  CHECK gt_base IS NOT INITIAL.

  SELECT bname addrnumber persnumber
    INTO TABLE lt_usr21
    FROM usr21
    FOR ALL ENTRIES IN gt_base
    WHERE bname = gt_base-bname.

  SORT lt_usr21 BY bname.

  LOOP AT gt_base INTO gs_base.
    READ TABLE lt_usr21 INTO ls_usr21
      WITH KEY bname = gs_base-bname BINARY SEARCH.
    CHECK sy-subrc = 0.

    gs_base-addrnumber = ls_usr21-addrnumber.
    gs_base-persnumber = ls_usr21-persnumber.
    MODIFY gt_base FROM gs_base TRANSPORTING addrnumber persnumber.
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  ENRICH_PA0105_EMAIL
*&---------------------------------------------------------------------*
*&  GT_BASE-USRID_LONG (and OBJPS/SPRPS/BEGDA/ENDDA, needed later for
*&  HR_INFOTYPE_OPERATION) <- PA0105 (SUBTY 0010, record valid today),
*&  via GT_BASE-PERNR
*&---------------------------------------------------------------------*
FORM enrich_pa0105_email.

  TYPES: BEGIN OF ty_pa0105_email,
           pernr      TYPE pa0105-pernr,
           objps      TYPE pa0105-objps,
           sprps      TYPE pa0105-sprps,
           begda      TYPE pa0105-begda,
           endda      TYPE pa0105-endda,
           usrid_long TYPE pa0105-usrid_long,
         END OF ty_pa0105_email.

  DATA: lt_pa0105 TYPE STANDARD TABLE OF ty_pa0105_email,
        ls_pa0105 TYPE ty_pa0105_email.

  CHECK gt_base IS NOT INITIAL.

  SELECT pernr objps sprps begda endda usrid_long
    INTO TABLE lt_pa0105
    FROM pa0105
    FOR ALL ENTRIES IN gt_base
    WHERE pernr = gt_base-pernr
      AND subty = '0010'
      AND begda <= sy-datum
      AND endda >= sy-datum.

  SORT lt_pa0105 BY pernr.

  LOOP AT gt_base INTO gs_base.
    READ TABLE lt_pa0105 INTO ls_pa0105
      WITH KEY pernr = gs_base-pernr BINARY SEARCH.
    CHECK sy-subrc = 0.

    gs_base-objps      = ls_pa0105-objps.
    gs_base-sprps      = ls_pa0105-sprps.
    gs_base-begda      = ls_pa0105-begda.
    gs_base-endda      = ls_pa0105-endda.
    gs_base-usrid_long = ls_pa0105-usrid_long.
    MODIFY gt_base FROM gs_base
      TRANSPORTING objps sprps begda endda usrid_long.
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  UPDATE_ADR6_SMTP
*&---------------------------------------------------------------------*
*&  ADR6-SMTP_ADDR (USR21-ADDRNUMBER/USR21-PERSNUMBER) <-
*&  GT_BASE-USRID_LONG, maintained via BAPI_USER_CHANGE so Business
*&  Address Services stays consistent (change documents, dependent
*&  tables) instead of a raw UPDATE against ADR6
*&---------------------------------------------------------------------*
FORM update_adr6_smtp.

  DATA: ls_address  TYPE bapiaddr3,
        ls_addressx TYPE bapiaddr3x,
        lt_return   TYPE STANDARD TABLE OF bapiret2,
        ls_return   TYPE bapiret2.

  LOOP AT gt_base INTO gs_base.

    CHECK gs_base-usrid_long IS NOT INITIAL.
    CHECK gs_base-addrnumber IS NOT INITIAL AND gs_base-persnumber IS NOT INITIAL.

    CLEAR: ls_address, ls_addressx, lt_return.
    ls_address-e_mail  = gs_base-usrid_long.
    ls_addressx-e_mail = abap_true.

    CALL FUNCTION 'BAPI_USER_CHANGE'
      EXPORTING
        username  = gs_base-bname
        address   = ls_address
        addressx  = ls_addressx
      TABLES
        return    = lt_return.

    READ TABLE lt_return INTO ls_return WITH KEY type = 'E'.
    IF sy-subrc = 0.
      ADD 1 TO gv_errors.
      WRITE: / 'Error ADR6 BNAME', gs_base-bname, ls_return-message.
      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    ELSE.
      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
        EXPORTING
          wait = abap_true.
      ADD 1 TO gv_updated_adr6.
    ENDIF.

  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  ENRICH_PA0001_KOSTL
*&---------------------------------------------------------------------*
*&  GT_BASE-KOSTL <- PA0001 (record with the latest AEDTM), via
*&  GT_BASE-PERNR
*&---------------------------------------------------------------------*
FORM enrich_pa0001_kostl.

  DATA: lt_pa0001 TYPE STANDARD TABLE OF ty_pa0001_kostl,
        ls_pa0001 TYPE ty_pa0001_kostl.

  CHECK gt_base IS NOT INITIAL.

  SELECT pernr kostl aedtm
    INTO TABLE lt_pa0001
    FROM pa0001
    FOR ALL ENTRIES IN gt_base
    WHERE pernr = gt_base-pernr.

  CHECK lt_pa0001 IS NOT INITIAL.

* Keep, per PERNR, the record with the latest AEDTM
  SORT lt_pa0001 BY pernr ASCENDING aedtm DESCENDING.
  DELETE ADJACENT DUPLICATES FROM lt_pa0001 COMPARING pernr.

  LOOP AT gt_base INTO gs_base.
    READ TABLE lt_pa0001 INTO ls_pa0001
      WITH KEY pernr = gs_base-pernr BINARY SEARCH.
    CHECK sy-subrc = 0.

    gs_base-kostl = ls_pa0001-kostl.
    MODIFY gt_base FROM gs_base TRANSPORTING kostl.
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  UPDATE_USR21_KOSTL
*&---------------------------------------------------------------------*
*&  USR21-KOSTL <- GT_BASE-KOSTL (PA0001-KOSTL), key USR02-BNAME
*&---------------------------------------------------------------------*
FORM update_usr21_kostl.

  DATA: lv_kostl_new TYPE usr21-kostl,
        lv_kostl_num TYPE i.

  LOOP AT gt_base INTO gs_base.

    CHECK gs_base-kostl IS NOT INITIAL.

* Convert through a numeric type so the value is re-padded/truncated
* to USR21-KOSTL's own length (drops PA0001-KOSTL's extra leading
* zeros instead of comparing/storing them as literal characters)
    lv_kostl_num = gs_base-kostl.
    CLEAR lv_kostl_new.
    lv_kostl_new = lv_kostl_num.

    UPDATE usr21 SET kostl = lv_kostl_new
      WHERE bname = gs_base-bname.

    IF sy-subrc = 0.
      COMMIT WORK.
      ADD 1 TO gv_updated_kostl.
    ELSE.
      ROLLBACK WORK.
      ADD 1 TO gv_errors.
    ENDIF.

  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  UPDATE_PA0105_USRID
*&---------------------------------------------------------------------*
*&  PA0105-USRID <- USR02-BNAME, key GT_BASE-PERNR / SUBTY = '0010'
*&  (the record valid today, already read in ENRICH_PA0105_EMAIL)
*&---------------------------------------------------------------------*
FORM update_pa0105_usrid.

  DATA: ls_return TYPE bapireturn1,
        ls_record TYPE p0105.

  LOOP AT gt_base INTO gs_base.

* Only records for which ENRICH_PA0105_EMAIL found a PA0105 (0010)
* record valid today
    CHECK gs_base-begda IS NOT INITIAL.

    CALL FUNCTION 'HR_EMPLOYEE_ENQUEUE'
      EXPORTING
        number         = gs_base-pernr
      EXCEPTIONS
        enqueue_failed = 1
        OTHERS         = 2.
    IF sy-subrc <> 0.
      ADD 1 TO gv_errors.
      CONTINUE.
    ENDIF.

    CLEAR ls_record.
    ls_record-infty      = '0105'.
    ls_record-pernr      = gs_base-pernr.
    ls_record-subty      = '0010'.
    ls_record-usrty      = '0010'.
    ls_record-objps      = gs_base-objps.
    ls_record-begda      = gs_base-begda.
    ls_record-endda      = gs_base-endda.
    ls_record-usrid_long = gs_base-usrid_long.
    ls_record-usrid      = gs_base-bname.

    CLEAR ls_return.

    CALL FUNCTION 'HR_INFOTYPE_OPERATION'
      EXPORTING
        infty         = '0105'
        number        = gs_base-pernr
        subtype       = '0010'
        objectid      = gs_base-objps
        lockindicator = gs_base-sprps
        validitybegin = gs_base-begda
        validityend   = gs_base-endda
        record        = ls_record
        operation     = 'MOD'
        tclas         = 'A'
        dialog_mode   = '0'
        nocommit      = space
      IMPORTING
        return        = ls_return.

    CALL FUNCTION 'HR_EMPLOYEE_DEQUEUE'
      EXPORTING
        number = gs_base-pernr.

    IF ls_return-type = 'E'.
      ADD 1 TO gv_errors.
      WRITE: / 'Error PA0105-USRID PERNR', gs_base-pernr, ls_return-message.
    ELSE.
      COMMIT WORK.
      ADD 1 TO gv_updated_usrid.
    ENDIF.

  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  DISPLAY_RESULTS
*&---------------------------------------------------------------------*
FORM display_results.

  WRITE: / 'ADR6-SMTP_ADDR actualizados   :', gv_updated_adr6.
  WRITE: / 'USR21-KOSTL actualizados      :', gv_updated_kostl.
  WRITE: / 'PA0105-USRID actualizados     :', gv_updated_usrid.
  WRITE: / 'Errores                       :', gv_errors.

ENDFORM.
