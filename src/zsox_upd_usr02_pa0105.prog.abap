*&---------------------------------------------------------------------*
*& Report ZSOX_UPD_USR02_PA0105
*&---------------------------------------------------------------------*
*& 1) USR02-ACCNT <- PA0105 (SUBTY 0001), via BAPI_USER_CHANGE
*& 2) PA0105 (SUBTY 0010) <- ZSOX_NETUSER, via HR_INFOTYPE_OPERATION
*&---------------------------------------------------------------------*
REPORT zsox_upd_usr02_pa0105.

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

*----------------------------------------------------------------------*
START-OF-SELECTION.

  PERFORM update_usr02_accnt.
  PERFORM update_pa0105_subty_0010.

  WRITE: / 'USR02-ACCNT actualizados      :', gv_updated_1.
  WRITE: / 'PA0105 (0010) actualizados    :', gv_updated_2.
  WRITE: / 'PA0105 (0010) creados         :', gv_created_2.
  WRITE: / 'Errores                       :', gv_errors.

*&---------------------------------------------------------------------*
*&      Form  UPDATE_USR02_ACCNT
*&---------------------------------------------------------------------*
*&  USR02.ACCNT <- PA0105.PERNR (SUBTY = '0001', USR02.BNAME = PA0105.USRID)
*&---------------------------------------------------------------------*
FORM update_usr02_accnt.

  DATA: lt_return     TYPE STANDARD TABLE OF bapiret2,
        ls_return     TYPE bapiret2,
        ls_logondata  TYPE bapilogond,
        ls_logondatax TYPE bapilogondx,
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
*&  - USRID_LONG <- ZSOX_NETUSER.ADID (si el registro ya existe y difiere)
*&  - crea el registro si no existe ninguno para ese PERNR/SUBTY
*&---------------------------------------------------------------------*
FORM update_pa0105_subty_0010.

  DATA: lt_return TYPE STANDARD TABLE OF bapireturn1,
        ls_return TYPE bapireturn1,
        ls_key    TYPE prelp-key,
        ls_record TYPE p0105,
        lv_pernr  TYPE pa0105-pernr.

  REFRESH gt_netuser.

  SELECT wikey adid
    INTO TABLE gt_netuser
    FROM zsox_netuser.

  LOOP AT gt_netuser INTO gs_netuser.

    CLEAR lv_pernr.
    lv_pernr = gs_netuser-wikey.

    CLEAR gs_pa0105.
    SELECT SINGLE *
      INTO gs_pa0105
      FROM pa0105
      WHERE pernr = lv_pernr
        AND subty = '0010'
        AND begda <= sy-datum
        AND endda >= sy-datum.

    IF sy-subrc = 0.

      CHECK gs_pa0105-usrid_long <> gs_netuser-adid.

      CLEAR ls_record.
      MOVE-CORRESPONDING gs_pa0105 TO ls_record.
      ls_record-usrid_long = gs_netuser-adid.

      CLEAR: lt_return, ls_key.

      CALL FUNCTION 'HR_INFOTYPE_OPERATION'
        EXPORTING
          infty         = '0105'
          number        = lv_pernr
          subtype       = '0010'
          objectid      = gs_pa0105-objps
          lockindicator = gs_pa0105-sprps
          validitybegin = gs_pa0105-begda
          validityend   = gs_pa0105-endda
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
