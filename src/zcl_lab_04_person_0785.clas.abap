CLASS zcl_lab_04_person_0785 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    METHODS:
      set_age IMPORTING i_age TYPE i,
      get_age EXPORTING e_age TYPE i.

  PROTECTED SECTION.
  PRIVATE SECTION.

    DATA: age TYPE i.

ENDCLASS.


CLASS zcl_lab_04_person_0785 IMPLEMENTATION.

  METHOD set_age.
    me->age = i_age.
  ENDMETHOD.

  METHOD get_age.
    e_age = me->age.
  ENDMETHOD.

ENDCLASS.
