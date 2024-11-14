CLASS zcl_lab_08_work_record_0785 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    CLASS-METHODS:
      open_new_record IMPORTING
                        i_date       TYPE zdate_0785
                        i_first_name TYPE string
                        i_last_name  TYPE string
                        i_surname    TYPE string OPTIONAL.

  PROTECTED SECTION.
  PRIVATE SECTION.

    CLASS-DATA: date       TYPE zdate_0785,
                first_name TYPE string,
                last_name  TYPE string,
                surname    TYPE string.

ENDCLASS.



CLASS zcl_lab_08_work_record_0785 IMPLEMENTATION.
  METHOD open_new_record.
    zcl_lab_08_work_record_0785=>date       = i_date.
    zcl_lab_08_work_record_0785=>first_name = i_first_name.
    zcl_lab_08_work_record_0785=>last_name  = i_last_name.
    zcl_lab_08_work_record_0785=>surname    = i_surname.
  ENDMETHOD.

ENDCLASS.
