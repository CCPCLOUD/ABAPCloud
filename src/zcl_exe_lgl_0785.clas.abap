CLASS zcl_exe_lgl_0785 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES: if_oo_adt_classrun.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_exe_lgl_0785 IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.

*  OUT->write( 'Done!!' ).

*    DATA: lo_obj_01 TYPE REF TO zcl_01_lgl_c311_0785.
*
*    CREATE OBJECT lo_obj_01.


    DATA(lo_obj01) = NEW zcl_01_lgl_c311_0785( ).


    lo_obj01->set_product( i_product = 'Producto 1' ).
    lo_obj01->get_product(
      IMPORTING
        e_product = DATA(lv_product)
    ).

*    out->write( lo_obj01->product ).
    out->write( lv_product ).

    zcl_01_lgl_c311_0785=>set_date( i_date = '07 de noviembre' ).
    zcl_01_lgl_c311_0785=>get_date(
      IMPORTING
        e_date = DATA(lv_date)
    ).

*    out->write( zcl_01_lgl_c311_0785=>date ).
    out->write( lv_date ).

  ENDMETHOD.

ENDCLASS.
