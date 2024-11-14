CLASS zcl_lab_05_flight_0785 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    METHODS:
      validate_flight IMPORTING
                        i_carrier_id    TYPE /dmo/flight-carrier_id
                        i_connection_id TYPE /dmo/flight-connection_id
                      RETURNING VALUE(rv_result) TYPE string.


  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.


CLASS zcl_lab_05_flight_0785 IMPLEMENTATION.
  METHOD validate_flight.
    SELECT SINGLE carrier_id FROM /dmo/flight
    WHERE carrier_id    EQ @i_carrier_id
    AND   connection_id EQ @i_connection_id
    INTO @DATA(lt_flight).

    IF lt_flight IS NOT INITIAL.
      rv_result = 'X'.
    ELSE.
      rv_result = space.
    ENDIF.


  ENDMETHOD.
ENDCLASS.
