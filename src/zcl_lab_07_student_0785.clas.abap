CLASS zcl_lab_07_student_0785 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    DATA: birth_date TYPE zdate_0785 READ-ONLY.

    METHODS:
      set_birth_date IMPORTING i_birth_date TYPE zdate_0785.


  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_lab_07_student_0785 IMPLEMENTATION.
  METHOD set_birth_date.
    me->birth_date = i_birth_date.
  ENDMETHOD.

ENDCLASS.
