*&---------------------------------------------------------------------*
*& Report ZSOX_UPD_USR02_PA0105
*&---------------------------------------------------------------------*
*& 1) USR02-ACCNT <- PA0105 (SUBTY 0001), via BAPI_USER_CHANGE
*& 2) PA0105 (SUBTY 0010) <- ZSOX_NETUSER, via HR_INFOTYPE_OPERATION
*&---------------------------------------------------------------------*
REPORT zsox_upd_usr02_pa0105.

INCLUDE zsox_upd_usr02_pa0105_top.
INCLUDE zsox_upd_usr02_pa0105_f01.

*----------------------------------------------------------------------*
START-OF-SELECTION.

  PERFORM update_usr02_accnt.
  PERFORM update_pa0105_subty_0010.

  WRITE: / 'USR02-ACCNT actualizados      :', gv_updated_1.
  WRITE: / 'PA0105 (0010) actualizados    :', gv_updated_2.
  WRITE: / 'PA0105 (0010) creados         :', gv_created_2.
  WRITE: / 'Errores                       :', gv_errors.
