CLASS zcl_lab_01_ejec_0785 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES: if_oo_adt_classrun.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_lab_01_ejec_0785 IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.


* 5.- Métodos de Instancia y métodos estáticos
    DATA(lo_age) = NEW zcl_lab_04_person_0785(  ).

    lo_age->set_age( i_age = '49' ).
    lo_age->get_age(
      IMPORTING
        e_age = DATA(lv_age) ).

    out->write( lv_age ).


* 6.- Métodos funcionales
    DATA(lo_flight) = NEW zcl_lab_05_flight_0785( ).

    lo_flight->validate_flight(
      EXPORTING
        i_carrier_id    = 'SQ'
        i_connection_id = '0001'
      RECEIVING
        rv_result       = DATA(lv_result) ).

    IF lv_result IS NOT INITIAL.
      lv_result = 'Equis'.
      out->write( lv_result ).
    ELSE.
      lv_result = 'Space'.
      out->write( lv_result ).
    ENDIF.

* 7.- Utilizar tipos de datos en clases
    DATA(lo_elements) = NEW zcl_lab_06_elements_0785( ).

    DATA: gs_elements TYPE lo_elements->ty_elem_objects.

    gs_elements-class     = 'Lab Class'.
    gs_elements-instance  = 'Lab Instance'.
    gs_elements-reference = 'Lab Reference'.

    lo_elements->set_objects( i_ms_objects = gs_elements ).

    out->write( lo_elements->ms_object ).

* 8.- Constantes en Clases
    out->write( |Constant 01: { lo_elements->c_01 } Constant 02: { lo_elements->c_02 } Constant 03: { lo_elements->c_03 } Constant 04: { lo_elements->c_04 } | ).

* 9.- READ-ONLY Restringir Acceso a Escritura

    DATA(lo_student) = NEW zcl_lab_07_student_0785( ).

    lo_student->set_birth_date( i_birth_date = '19741107' ).

    out->write( lo_student->birth_date ).


* 10.- Parámetro Opcional

    zcl_lab_08_work_record_0785=>open_new_record(
      i_date       = '19741107'
      i_first_name = 'Cristóbal'
      i_last_name  = 'Contreras'
      i_surname    = 'Pérez' ).


* 11.- Autoreferencia

    DATA(lo_account) = NEW zcl_lab_09_account_0785( ).

    lo_account->set_iban( iban = 'GB29 NWBK 6016 1331 9268 19' ).
    lo_account->get_iban(
      IMPORTING
        iban = DATA(lv_iban) ).

    out->write( lv_iban ).


* 1.- Constructores de instancia y constructor estático

    DATA(lo_constructor) = NEW zcl_lab_10_constructor_0785(  ).

    out->write( lo_constructor->log ).

  ENDMETHOD.

ENDCLASS.
