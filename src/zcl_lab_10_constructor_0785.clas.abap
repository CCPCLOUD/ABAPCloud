CLASS zcl_lab_10_constructor_0785 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    METHODS constructor.

    CLASS-METHODS class_constructor.

    CLASS-DATA log TYPE string.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zcl_lab_10_constructor_0785 IMPLEMENTATION.

  METHOD constructor.
    zcl_lab_10_constructor_0785=>log = | { zcl_lab_10_constructor_0785=>log }-Instance Constructor ---> |.
  ENDMETHOD.

  METHOD class_constructor.
   zcl_lab_10_constructor_0785=>log = | { zcl_lab_10_constructor_0785=>log }-Static Constructor ---> |.
  ENDMETHOD.

ENDCLASS.
