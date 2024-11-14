CLASS zcl_lab_03_contract_0785 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    DATA: cntr_type TYPE c LENGTH 2.

    METHODS: set_creation_date IMPORTING i_creation_date TYPE zdate_0785.

  PROTECTED SECTION.

    DATA: creation_date TYPE zdate_0785.

  PRIVATE SECTION.

    DATA: client TYPE string.


ENDCLASS.



CLASS zcl_lab_03_contract_0785 IMPLEMENTATION.
  METHOD set_creation_date.

    me->creation_date = i_creation_date.

  ENDMETHOD.

ENDCLASS.
