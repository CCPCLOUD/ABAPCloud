CLASS zcl_lab_02_product_0785 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    METHODS:
      set_product IMPORTING i_product TYPE matnr,
      set_creationdate IMPORTING i_creationdate TYPE zdate_0785.

  PROTECTED SECTION.
  PRIVATE SECTION.

    DATA: product       TYPE matnr,
          creation_date TYPE zdate_0785.

ENDCLASS.



CLASS zcl_lab_02_product_0785 IMPLEMENTATION.

  METHOD set_product.
    me->product = i_product.
  ENDMETHOD.

  METHOD set_creationdate.
    me->creation_date = i_creationdate.
  ENDMETHOD.

ENDCLASS.
