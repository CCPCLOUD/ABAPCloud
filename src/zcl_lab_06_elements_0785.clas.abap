CLASS zcl_lab_06_elements_0785 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    TYPES: BEGIN OF ty_elem_objects,
             class     TYPE string,
             instance  TYPE string,
             reference TYPE string,
           END OF ty_elem_objects.

    DATA: ms_object TYPE ty_elem_objects.

    CONSTANTS:
      c_01 TYPE string VALUE 'Program',
      c_02 TYPE string VALUE 'Report',
      c_03 TYPE string VALUE 'Include',
      c_04 TYPE string VALUE 'Method'.

    METHODS:
      set_objects IMPORTING i_ms_objects TYPE ty_elem_objects.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_lab_06_elements_0785 IMPLEMENTATION.
  METHOD set_objects.
    me->ms_object-class     = i_ms_objects-class.
    me->ms_object-instance  = i_ms_objects-instance.
    me->ms_object-reference = i_ms_objects-reference.
  ENDMETHOD.

ENDCLASS.
