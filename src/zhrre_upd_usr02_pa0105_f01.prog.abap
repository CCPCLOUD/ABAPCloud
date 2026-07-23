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
        lv_accnt_new  TYPE usr02-accnt.

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

    CLEAR lv_accnt_new.
    lv_accnt_new = gs_usr02_pa0105-pernr.

    CHECK lv_accnt_new <> gs_usr02_pa0105-accnt.

    CLEAR: ls_logondata, ls_logondatax, lt_return.
    ls_logondata-accnt  = lv_accnt_new.
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
*&  - USRID_LONG <- ZSOX_NETUSER.ADID (if the record already exists and
*&    differs)
*&  - creates the record if none exists for that PERNR/SUBTY
*&---------------------------------------------------------------------*
FORM update_pa0105_subty_0010.

  DATA: lt_return TYPE STANDARD TABLE OF bapireturn1,
        ls_return TYPE bapireturn1,
        ls_key    TYPE prelp-pskey,
        ls_record TYPE p0105,
        lv_pernr  TYPE pa0105-pernr.

  REFRESH gt_netuser.

* Single bulk lookup: LEFT OUTER JOIN so unmatched ZSOX_NETUSER rows
* (no PA0105 record yet) come back with PA0105 fields initial, instead
* of one SELECT SINGLE per row. A plain INNER JOIN cannot be used here
* since it would drop the rows that still need to be created.
  SELECT z~wikey z~adid
         p~pernr p~objps p~sprps p~begda p~endda p~usrid_long
    INTO TABLE gt_netuser
    FROM zsox_netuser AS z
    LEFT OUTER JOIN pa0105 AS p
      ON p~pernr = z~wikey
     AND p~subty = '0010'
     AND p~begda <= sy-datum
     AND p~endda >= sy-datum.

  LOOP AT gt_netuser INTO gs_netuser.

* Skip WIKEY values that are not a valid PERNR (e.g. 'TEMP', 'TEST')
    CHECK gs_netuser-wikey CO '0123456789 '.

    CLEAR lv_pernr.
    lv_pernr = gs_netuser-wikey.

    IF gs_netuser-pernr IS NOT INITIAL.

      CHECK gs_netuser-usrid_long <> gs_netuser-adid.

      CLEAR ls_record.
      ls_record-pernr      = gs_netuser-pernr.
      ls_record-subty      = '0010'.
      ls_record-objps      = gs_netuser-objps.
      ls_record-begda      = gs_netuser-begda.
      ls_record-endda      = gs_netuser-endda.
      ls_record-usrid_long = gs_netuser-adid.

      CLEAR: lt_return, ls_key.

      CALL FUNCTION 'HR_INFOTYPE_OPERATION'
        EXPORTING
          infty         = '0105'
          number        = lv_pernr
          subtype       = '0010'
          objectid      = gs_netuser-objps
          lockindicator = gs_netuser-sprps
          validitybegin = gs_netuser-begda
          validityend   = gs_netuser-endda
          record        = ls_record
          operation     = 'MOD'
          tclas         = 'A'
          dialog_mode   = '0'
          nocommit      = space
        IMPORTING
          key           = ls_key
        TABLES
          return        = lt_return.

      READ TABLE lt_return INTO ls_return WITH KEY type = 'E'.
      IF sy-subrc = 0.
        ADD 1 TO gv_errors.
      ELSE.
        ADD 1 TO gv_updated_2.
      ENDIF.

    ELSE.

      CLEAR ls_record.
      ls_record-pernr      = lv_pernr.
      ls_record-subty      = '0010'.
      ls_record-begda      = sy-datum.
      ls_record-endda      = '99991231'.
      ls_record-usrid_long = gs_netuser-adid.

      CLEAR: lt_return, ls_key.

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
          key           = ls_key
        TABLES
          return        = lt_return.

      READ TABLE lt_return INTO ls_return WITH KEY type = 'E'.
      IF sy-subrc = 0.
        ADD 1 TO gv_errors.
      ELSE.
        ADD 1 TO gv_created_2.
      ENDIF.

    ENDIF.

  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  UPDATE_USR21_KOSTL
*&---------------------------------------------------------------------*
*&  USR21.KOSTL <- PA0001.KOSTL (record with the latest PA0001.AEDTM
*&  for the PERNR), USR21.PERSNUMBER = PA0001.PERNR
*&---------------------------------------------------------------------*
FORM update_usr21_kostl.

  DATA: lt_usr21_cpy TYPE STANDARD TABLE OF ty_usr21,
        lv_kostl_new TYPE pa0001-kostl.

  REFRESH: gt_usr21, gt_pa0001_kostl.

  SELECT bname persnumber kostl
    INTO TABLE gt_usr21
    FROM usr21.

  CHECK gt_usr21 IS NOT INITIAL.

* Convert USR21-PERSNUMBER to PA0001-PERNR format
  LOOP AT gt_usr21 INTO gs_usr21.
    gs_usr21-pernr = gs_usr21-persnumber.
    MODIFY gt_usr21 FROM gs_usr21 TRANSPORTING pernr.
  ENDLOOP.

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

    CHECK gs_usr21-pernr IS NOT INITIAL.

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
