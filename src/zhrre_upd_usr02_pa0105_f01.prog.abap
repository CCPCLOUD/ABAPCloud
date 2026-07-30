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
* Description            : <Objective of the change>
* Functional Consultant: : <Functional Consultant Name>
* Abap Consultant        : <ABAP Consultant Name>
* Modification date      : YYYY.MM.DD
* Ticket                 : ######
*----------------------------------------------------------------------

*&---------------------------------------------------------------------*
*&      Form  MAIN
*&---------------------------------------------------------------------*
FORM main.

* Update USR02-ACCNT from PA0105 (SUBTY 0001)
  PERFORM update_usr02_accnt.

* Update/create PA0105 (SUBTY 0010) from ZSOX_NETUSER
  PERFORM update_pa0105_subty_0010.

* Update USR21-KOSTL from PA0001 (record with the latest AEDTM)
  PERFORM update_usr21_kostl.

* Show the results summary
  PERFORM display_results.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  UPDATE_USR02_ACCNT
*&---------------------------------------------------------------------*
*&  USR02.ACCNT <- PA0105.PERNR (SUBTY = '0001', USR02.BNAME = PA0105.USRID)
*&---------------------------------------------------------------------*
FORM update_usr02_accnt.

  DATA: lt_return     TYPE STANDARD TABLE OF bapiret2,
        ls_return     TYPE bapiret2,
        ls_logondata  TYPE bapilogond,
        ls_logondatax TYPE bapilogonx,
        lv_accnt_new  TYPE usr02-accnt,
        lv_accnt_cmp  TYPE usr02-accnt,
        lv_accnt_cur  TYPE usr02-accnt.

  REFRESH gt_usr02_pa0105.

  SELECT u~bname u~accnt p~pernr
    INTO TABLE gt_usr02_pa0105
    FROM usr02 AS u
    INNER JOIN pa0105 AS p
      ON p~usrid = u~bname
     AND p~subty = '0001'
     AND p~begda <= sy-datum
     AND p~endda >= sy-datum.

  LOOP AT gt_usr02_pa0105 INTO gs_usr02_pa0105.

* PERNR without leading zeros, to compare/store like USR02-ACCNT
    CLEAR lv_accnt_new.
    WRITE gs_usr02_pa0105-pernr TO lv_accnt_new NO-ZERO.

* Compare ignoring blanks: NO-ZERO left-justifies, while the existing
* ACCNT value may be padded on either side
    lv_accnt_cmp = lv_accnt_new.
    CONDENSE lv_accnt_cmp NO-GAPS.
    lv_accnt_cur = gs_usr02_pa0105-accnt.
    CONDENSE lv_accnt_cur NO-GAPS.

    CHECK lv_accnt_cmp <> lv_accnt_cur.

    CLEAR: ls_logondata, ls_logondatax, lt_return.
    ls_logondata-accnt  = lv_accnt_cmp.
    ls_logondatax-accnt = abap_true.

    CALL FUNCTION 'BAPI_USER_CHANGE'
      EXPORTING
        username   = gs_usr02_pa0105-bname
        logondata  = ls_logondata
        logondatax = ls_logondatax
      TABLES
        return     = lt_return.

    READ TABLE lt_return INTO ls_return WITH KEY type = 'E'.
    IF sy-subrc = 0.
      ADD 1 TO gv_errors.
      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    ELSE.
      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
        EXPORTING
          wait = abap_true.
      ADD 1 TO gv_updated_1.
    ENDIF.

  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  UPDATE_PA0105_SUBTY_0010
*&---------------------------------------------------------------------*
*&  PA0105 (SUBTY = '0010', PERNR = ZSOX_NETUSER.WIKEY):
*&  - Filters ZSOX_NETUSER to rows whose WIKEY exists as PERNR in PA0002
*&  - USRID_LONG <- ZSOX_NETUSER.ADID (if the record already exists and
*&    differs)
*&  - creates the record if none exists for that PERNR/SUBTY
*&---------------------------------------------------------------------*
FORM update_pa0105_subty_0010.

  DATA: ls_return      TYPE bapireturn1,
        ls_record      TYPE p0105,
        lv_pernr       TYPE pa0105-pernr,
        lt_netuser_cpy TYPE STANDARD TABLE OF ty_netuser,
        lt_pa0002      TYPE STANDARD TABLE OF pa0002-pernr.

  REFRESH: gt_netuser, gt_pa0105_comm.

  SELECT wikey adid
    INTO TABLE gt_netuser
    FROM zsox_netuser.

* Convert WIKEY to PERNR format (a plain MOVE performs the implicit
* CHAR -> NUMC zero-padding). Comparing WIKEY directly against PERNR
* inside a JOIN/WHERE pushed to the database skips that conversion, so
* '1975' would never match the stored '00001975' - hence doing it here.
* Rows that are not numeric (e.g. 'TEMP', 'TEST') are dropped.
  LOOP AT gt_netuser INTO gs_netuser.
    IF gs_netuser-wikey CO '0123456789 '.
      gs_netuser-pernr = gs_netuser-wikey.
      MODIFY gt_netuser FROM gs_netuser TRANSPORTING pernr.
    ELSE.
      DELETE gt_netuser.
    ENDIF.
  ENDLOOP.

  CHECK gt_netuser IS NOT INITIAL.

* Copy without duplicates to check which PERNR actually exist in PA0002
  lt_netuser_cpy[] = gt_netuser.
  SORT lt_netuser_cpy BY pernr.
  DELETE ADJACENT DUPLICATES FROM lt_netuser_cpy COMPARING pernr.

  SELECT pernr
    INTO TABLE lt_pa0002
    FROM pa0002
    FOR ALL ENTRIES IN lt_netuser_cpy
    WHERE pernr = lt_netuser_cpy-pernr.

  SORT lt_pa0002.
  DELETE ADJACENT DUPLICATES FROM lt_pa0002.

* Keep only ZSOX_NETUSER rows whose PERNR actually exists in PA0002
  LOOP AT gt_netuser INTO gs_netuser.
    READ TABLE lt_pa0002 TRANSPORTING NO FIELDS
      WITH KEY table_line = gs_netuser-pernr BINARY SEARCH.
    IF sy-subrc <> 0.
      DELETE gt_netuser.
    ENDIF.
  ENDLOOP.

  CHECK gt_netuser IS NOT INITIAL.

* Copy without duplicates for the PA0105 FOR ALL ENTRIES lookup
  REFRESH lt_netuser_cpy.
  lt_netuser_cpy[] = gt_netuser.
  SORT lt_netuser_cpy BY pernr.
  DELETE ADJACENT DUPLICATES FROM lt_netuser_cpy COMPARING pernr.

  SELECT pernr objps sprps begda endda usrid_long
    INTO TABLE gt_pa0105_comm
    FROM pa0105
    FOR ALL ENTRIES IN lt_netuser_cpy
    WHERE pernr = lt_netuser_cpy-pernr
      AND subty = '0010'.

  FREE lt_netuser_cpy.

* Flag, per row, the PA0105 record that is valid today
  LOOP AT gt_pa0105_comm INTO gs_pa0105_comm.
    IF gs_pa0105_comm-begda <= sy-datum
       AND gs_pa0105_comm-endda >= sy-datum.
      gs_pa0105_comm-is_valid = abap_true.
    ELSE.
      gs_pa0105_comm-is_valid = abap_false.
    ENDIF.
    MODIFY gt_pa0105_comm FROM gs_pa0105_comm TRANSPORTING is_valid.
  ENDLOOP.

* Keep, per PERNR, the record valid today (if any)
  SORT gt_pa0105_comm BY pernr ASCENDING is_valid DESCENDING.
  DELETE ADJACENT DUPLICATES FROM gt_pa0105_comm COMPARING pernr.

  LOOP AT gt_netuser INTO gs_netuser.

    lv_pernr = gs_netuser-pernr.

    READ TABLE gt_pa0105_comm INTO gs_pa0105_comm
      WITH KEY pernr = gs_netuser-pernr BINARY SEARCH.

    IF sy-subrc = 0 AND gs_pa0105_comm-is_valid = abap_true.

      CHECK gs_pa0105_comm-usrid_long <> gs_netuser-adid.

      CALL FUNCTION 'HR_EMPLOYEE_ENQUEUE'
        EXPORTING
          number         = lv_pernr
        EXCEPTIONS
          enqueue_failed = 1
          OTHERS         = 2.
      IF sy-subrc <> 0.
        ADD 1 TO gv_errors.
        CONTINUE.
      ENDIF.

      CLEAR ls_record.
      ls_record-infty      = '0105'.
      ls_record-pernr      = gs_pa0105_comm-pernr.
      ls_record-subty      = '0010'.
      ls_record-objps      = gs_pa0105_comm-objps.
      ls_record-begda      = gs_pa0105_comm-begda.
      ls_record-endda      = gs_pa0105_comm-endda.
      ls_record-usrid_long = gs_netuser-adid.

      CLEAR ls_return.

      CALL FUNCTION 'HR_INFOTYPE_OPERATION'
        EXPORTING
          infty         = '0105'
          number        = lv_pernr
          subtype       = '0010'
          objectid      = gs_pa0105_comm-objps
          lockindicator = gs_pa0105_comm-sprps
          validitybegin = gs_pa0105_comm-begda
          validityend   = gs_pa0105_comm-endda
          record        = ls_record
          operation     = 'MOD'
          tclas         = 'A'
          dialog_mode   = '0'
          nocommit      = space
        IMPORTING
          return        = ls_return.

      CALL FUNCTION 'HR_EMPLOYEE_DEQUEUE'
        EXPORTING
          number = lv_pernr.

      IF ls_return-type = 'E'.
        ADD 1 TO gv_errors.
        WRITE: / 'Error MOD PERNR', lv_pernr, ls_return-message.
      ELSE.
        COMMIT WORK.
        ADD 1 TO gv_updated_2.
      ENDIF.

    ELSE.

      CALL FUNCTION 'HR_EMPLOYEE_ENQUEUE'
        EXPORTING
          number         = lv_pernr
        EXCEPTIONS
          enqueue_failed = 1
          OTHERS         = 2.
      IF sy-subrc <> 0.
        ADD 1 TO gv_errors.
        CONTINUE.
      ENDIF.

      CLEAR ls_record.
      ls_record-infty      = '0105'.
      ls_record-pernr      = lv_pernr.
      ls_record-subty      = '0010'.
      ls_record-begda      = sy-datum.
      ls_record-endda      = '99991231'.
      ls_record-usrid_long = gs_netuser-adid.

      CLEAR ls_return.

      CALL FUNCTION 'HR_INFOTYPE_OPERATION'
        EXPORTING
          infty         = '0105'
          number        = lv_pernr
          subtype       = '0010'
          objectid      = space
          lockindicator = space
          validitybegin = sy-datum
          validityend   = '99991231'
          record        = ls_record
          operation     = 'INS'
          tclas         = 'A'
          dialog_mode   = '0'
          nocommit      = space
        IMPORTING
          return        = ls_return.

      CALL FUNCTION 'HR_EMPLOYEE_DEQUEUE'
        EXPORTING
          number = lv_pernr.

      IF ls_return-type = 'E'.
        ADD 1 TO gv_errors.
        WRITE: / 'Error INS PERNR', lv_pernr, ls_return-message.
      ELSE.
        COMMIT WORK.
        ADD 1 TO gv_created_2.
      ENDIF.

    ENDIF.

  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  UPDATE_USR21_KOSTL
*&---------------------------------------------------------------------*
*&  USR21.KOSTL <- PA0001.KOSTL (record with the latest PA0001.AEDTM
*&  for the PERNR), USR21.BNAME = USR02.BNAME, USR02.ACCNT = PA0001.PERNR
*&---------------------------------------------------------------------*
FORM update_usr21_kostl.

  DATA: lt_usr21_cpy TYPE STANDARD TABLE OF ty_usr21,
        lv_kostl_new TYPE pa0001-kostl.

  REFRESH: gt_usr21, gt_pa0001_kostl.

  SELECT u21~bname u21~kostl u02~accnt
    INTO TABLE gt_usr21
    FROM usr21 AS u21
    INNER JOIN usr02 AS u02
      ON u02~bname = u21~bname.

  CHECK gt_usr21 IS NOT INITIAL.

* Convert USR02-ACCNT to PA0001-PERNR format (a plain MOVE performs the
* implicit CHAR -> NUMC zero-padding); drop rows where ACCNT is not
* numeric (e.g. blank/not yet set by UPDATE_USR02_ACCNT)
  LOOP AT gt_usr21 INTO gs_usr21.
    IF gs_usr21-accnt IS NOT INITIAL AND gs_usr21-accnt CO '0123456789 '.
      gs_usr21-pernr = gs_usr21-accnt.
      MODIFY gt_usr21 FROM gs_usr21 TRANSPORTING pernr.
    ELSE.
      DELETE gt_usr21.
    ENDIF.
  ENDLOOP.

  CHECK gt_usr21 IS NOT INITIAL.

* Copy without duplicates for the FOR ALL ENTRIES lookup
  lt_usr21_cpy[] = gt_usr21.
  SORT lt_usr21_cpy BY pernr.
  DELETE ADJACENT DUPLICATES FROM lt_usr21_cpy COMPARING pernr.

  SELECT pernr kostl aedtm
    INTO TABLE gt_pa0001_kostl
    FROM pa0001
    FOR ALL ENTRIES IN lt_usr21_cpy
    WHERE pernr = lt_usr21_cpy-pernr.

  FREE lt_usr21_cpy.

  CHECK gt_pa0001_kostl IS NOT INITIAL.

* Keep, per PERNR, the record with the latest AEDTM
  SORT gt_pa0001_kostl BY pernr ASCENDING aedtm DESCENDING.
  DELETE ADJACENT DUPLICATES FROM gt_pa0001_kostl COMPARING pernr.

  LOOP AT gt_usr21 INTO gs_usr21.

    READ TABLE gt_pa0001_kostl INTO gs_pa0001_kostl
      WITH KEY pernr = gs_usr21-pernr BINARY SEARCH.
    CHECK sy-subrc = 0.

    CLEAR lv_kostl_new.
    lv_kostl_new = gs_pa0001_kostl-kostl.

    CHECK lv_kostl_new <> gs_usr21-kostl.

    UPDATE usr21 SET kostl = lv_kostl_new
      WHERE bname = gs_usr21-bname.

    IF sy-subrc = 0.
      COMMIT WORK.
      ADD 1 TO gv_updated_3.
    ELSE.
      ROLLBACK WORK.
      ADD 1 TO gv_errors.
    ENDIF.

  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  DISPLAY_RESULTS
*&---------------------------------------------------------------------*
FORM display_results.

  WRITE: / 'USR02-ACCNT actualizados      :', gv_updated_1.
  WRITE: / 'PA0105 (0010) actualizados    :', gv_updated_2.
  WRITE: / 'PA0105 (0010) creados         :', gv_created_2.
  WRITE: / 'USR21-KOSTL actualizados      :', gv_updated_3.
  WRITE: / 'Errores                       :', gv_errors.

ENDFORM.
