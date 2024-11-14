CLASS zcl_01_lgl_c311_0785 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

** Attributes
*    DATA: product TYPE string.
*    CLASS-DATA: Date TYPE string.

* Methods
    METHODS:
      set_product IMPORTING i_product TYPE string,
      get_product EXPORTING e_product TYPE string.

    CLASS-METHODS:
      set_date IMPORTING i_date TYPE string,
      get_date EXPORTING e_date TYPE string.


  PROTECTED SECTION.
  PRIVATE SECTION.
* Attributes
    DATA: product TYPE string.
    CLASS-DATA: Date TYPE string.

ENDCLASS.


CLASS zcl_01_lgl_c311_0785 IMPLEMENTATION.
  METHOD set_product.
    product = i_product.
  ENDMETHOD.

  METHOD set_date.
    date = i_date.
  ENDMETHOD.

  METHOD get_date.
    e_date = date.
  ENDMETHOD.

  METHOD get_product.
    e_product = product.
  ENDMETHOD.

ENDCLASS.
