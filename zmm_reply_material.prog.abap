*&---------------------------------------------------------------------*
*& Report ZTEST21
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zmm_reply_material..

* Data Declarations
DATA: lt_matnr                    TYPE STANDARD TABLE OF matnr,
      lv_matnr                    TYPE matnr,
      ls_clientdata_all           TYPE bapi_mara_ga,
      ls_plantdata_all            TYPE bapi_marc_ga,
      ls_planningdata_all         TYPE bapi_mpgd_ga,
      ls_storagelocationdata_all  TYPE bapi_mard_ga,
      ls_warehousenumberdata_all  TYPE bapi_mlgn_ga,
      ls_storagetypedata_all      TYPE  bapi_mlgt_ga,
      ls_prodresourcetooldata_all TYPE bapi_mfhm_ga,
      ls_valuationdata_all        TYPE bapi_mbew_ga,
      ls_salesdata_all            TYPE bapi_mvke_ga,
      lt_taxclassifications_all   TYPE STANDARD TABLE OF bapi_mlan_ga,
      lt_materialdescription_all  TYPE STANDARD TABLE OF bapi_makt_ga.

DATA: ls_headdata            TYPE bapimathead,
      ls_clientdata          TYPE bapi_mara,
      ls_clientdatax         TYPE bapi_marax,
      ls_plantdata           TYPE bapi_marc,
      ls_plantdatax          TYPE bapi_marcx,
      ls_salesdata           TYPE bapi_mvke,
      ls_salesdatax          TYPE bapi_mvkex,
      ls_valuationdata       TYPE bapi_mbew,
      ls_valuationdatax      TYPE bapi_mbewx,
      lt_taxclassification   TYPE STANDARD TABLE OF bapi_mlan,
      lt_materialdescription TYPE STANDARD TABLE OF bapi_makt.


DATA: ls_return   TYPE                      bapiret2,
      lt_messages TYPE STANDARD TABLE OF    bapi_matreturn2.

SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-t01.
SELECT-OPTIONS: s_matnr FOR ls_headdata-material.
PARAMETERS: p_vkorg TYPE vkorg OBLIGATORY.
PARAMETERS: p_plant TYPE werks_d OBLIGATORY.
PARAMETERS: p_loadgr TYPE ladgr OBLIGATORY.
PARAMETERS: p_prstlo TYPE lgpro OBLIGATORY.
PARAMETERS: p_proctr TYPE prctr OBLIGATORY.
SELECTION-SCREEN END OF BLOCK b01 .

SELECTION-SCREEN BEGIN OF BLOCK b02 WITH FRAME TITLE TEXT-t02.
PARAMETERS: p_cpmat TYPE mara-matnr.
PARAMETERS: p_cpso TYPE vkorg OBLIGATORY.
PARAMETERS: p_cpdc TYPE vtweg OBLIGATORY.
PARAMETERS: p_cppl TYPE werks_d OBLIGATORY.
PARAMETERS: p_cpval TYPE bwkey OBLIGATORY.
SELECTION-SCREEN END OF BLOCK b02 .


START-OF-SELECTION .

  IF p_cpmat IS NOT INITIAL.
    SELECT matnr
      FROM mara
      INTO TABLE lt_matnr
    WHERE matnr EQ p_cpmat.
  ELSE.
    SELECT matnr
      FROM mara
      INTO TABLE lt_matnr
    WHERE matnr IN s_matnr.
  ENDIF.

  LOOP AT lt_matnr ASSIGNING FIELD-SYMBOL(<fs_matnr>).

    CLEAR: ls_clientdata_all,
           ls_plantdata_all,
*           ls_forecastparameters_all,
           ls_planningdata_all,
           ls_storagelocationdata_all,
           ls_valuationdata_all,
           ls_warehousenumberdata_all,
           ls_salesdata_all,
           ls_storagetypedata_all.

    CLEAR lt_taxclassifications_all[].

    CLEAR: ls_headdata,
          ls_clientdata,
          ls_clientdatax,
          ls_plantdata,
          ls_plantdatax,
          ls_salesdata,
          ls_salesdatax,
          ls_valuationdata,
          ls_valuationdatax.

    CLEAR lt_taxclassification[].


    IF NOT p_cpmat IS INITIAL.
      lv_matnr = p_cpmat.
    ELSE.
      lv_matnr = <fs_matnr> .
    ENDIF.

* Read Material Data
    CALL FUNCTION 'BAPI_MATERIAL_GETALL'
      EXPORTING
        material            = lv_matnr
        plant               = p_cppl
        salesorganisation   = p_cpso
        distributionchannel = p_cpdc
        valuationarea       = p_cpval
      IMPORTING
        clientdata          = ls_clientdata_all
        plantdata           = ls_plantdata_all
*       forecastparameters  = ls_forecastparameters_all
*       planningdata        = ls_planningdata_all
        storagelocationdata = ls_storagelocationdata_all
        valuationdata       = ls_valuationdata_all
        warehousenumberdata = ls_warehousenumberdata_all
        salesdata           = ls_salesdata_all
        storagetypedata     = ls_storagetypedata_all
*       productionresourcetooldata = ls_prodresourcetooldata_all.
*       lifovaluationdata   = ls_lifovaluationdata_all.
      TABLES
        taxclassifications  = lt_taxclassifications_all
        materialdescription = lt_materialdescription_all.

    ls_headdata-basic_view      = abap_true.
*    ls_headdata-purchase_view   = abap_true.
    IF ls_valuationdata_all IS NOT INITIAL.
      ls_headdata-account_view    = abap_true.
      ls_headdata-cost_view       = abap_true.
    ENDIF.

    IF ls_salesdata_all IS NOT INITIAL .
      ls_headdata-sales_view       = abap_true.
    ENDIF.

    IF ls_plantdata_all IS NOT INITIAL .
      ls_headdata-mrp_view        = abap_true.
      ls_headdata-work_sched_view = abap_true.
    ENDIF.

    IF ls_storagelocationdata_all IS NOT INITIAL .
      ls_headdata-storage_view    = abap_true.
    ENDIF.


*   Header
    DATA: lo_strucdescr TYPE REF TO cl_abap_structdescr.
    lo_strucdescr  ?= cl_abap_typedescr=>describe_by_data( ls_clientdata ).

    IF ls_clientdata_all IS NOT INITIAL.
      MOVE-CORRESPONDING ls_clientdata_all TO ls_headdata.
      IF p_cpmat IS NOT INITIAL AND s_matnr-low IS NOT INITIAL.
        ls_headdata-material = s_matnr-low.

        CALL FUNCTION 'CONVERSION_EXIT_MATNL_INPUT'
          EXPORTING
            input        = s_matnr-low
          IMPORTING
            output       = ls_headdata-material_external
          EXCEPTIONS
            length_error = 1
            OTHERS       = 2.
        IF sy-subrc <> 0.
* Implement suitable error handling here
        ENDIF.

        CLEAR ls_headdata-material_guid.
      ENDIF.
      MOVE-CORRESPONDING ls_clientdata_all TO ls_clientdata.
      LOOP AT lo_strucdescr->components ASSIGNING FIELD-SYMBOL(<fs_components>).
        ASSIGN COMPONENT <fs_components>-name OF STRUCTURE ls_clientdata TO FIELD-SYMBOL(<fs_value>).
        IF <fs_value> IS ASSIGNED AND <fs_value> IS NOT INITIAL.
          ASSIGN COMPONENT <fs_components>-name OF STRUCTURE ls_clientdatax TO FIELD-SYMBOL(<fs_value_x>).
          IF <fs_value_x> IS ASSIGNED .
            <fs_value_x> = abap_true.
            UNASSIGN <fs_value_x> .
          ENDIF.
          UNASSIGN <fs_value>.
        ENDIF.
      ENDLOOP.
    ENDIF.

    IF ls_plantdata_all IS NOT INITIAL.
      lo_strucdescr  ?= cl_abap_typedescr=>describe_by_data( ls_plantdata ).
      MOVE-CORRESPONDING ls_plantdata_all TO ls_plantdata.
      ls_plantdata-loadinggrp = p_loadgr .
      ls_plantdata-iss_st_loc = p_prstlo.
      ls_plantdata-sloc_exprc = p_prstlo.
      ls_plantdata-profit_ctr = p_proctr.
      CLEAR ls_plantdata-comm_code .
      LOOP AT lo_strucdescr->components ASSIGNING <fs_components>.
        ASSIGN COMPONENT <fs_components>-name OF STRUCTURE ls_plantdata TO <fs_value>.
        IF <fs_value> IS ASSIGNED AND <fs_value> IS NOT INITIAL.
          ASSIGN COMPONENT <fs_components>-name OF STRUCTURE ls_plantdatax TO <fs_value_x>.
          IF <fs_value_x> IS ASSIGNED .
            <fs_value_x> = abap_true.
            UNASSIGN <fs_value_x> .
          ENDIF.
          UNASSIGN <fs_value>.
        ENDIF.
      ENDLOOP.

      ls_plantdata-plant = p_plant.
      ls_plantdatax-plant = p_plant.
    ENDIF.

    IF ls_salesdata_all IS NOT INITIAL.
      lo_strucdescr  ?= cl_abap_typedescr=>describe_by_data( ls_salesdata ).
      MOVE-CORRESPONDING ls_salesdata_all TO ls_salesdata.
      ls_salesdata-delyg_plnt = p_vkorg.
*      ls_salesdata
      LOOP AT lo_strucdescr->components ASSIGNING <fs_components>.
        ASSIGN COMPONENT <fs_components>-name OF STRUCTURE ls_salesdata TO <fs_value>.
        IF <fs_value> IS ASSIGNED AND <fs_value> IS NOT INITIAL.
          ASSIGN COMPONENT <fs_components>-name OF STRUCTURE ls_salesdatax TO <fs_value_x>.
          IF <fs_value_x> IS ASSIGNED .
            <fs_value_x> = abap_true.
            UNASSIGN <fs_value_x> .
          ENDIF.
          UNASSIGN <fs_value>.
        ENDIF.
      ENDLOOP.

      ls_salesdata-sales_org = p_vkorg.
      ls_salesdatax-sales_org = p_vkorg.
      ls_salesdata-distr_chan = p_cpdc.
      ls_salesdatax-distr_chan = p_cpdc.
    ENDIF.

    IF  ls_valuationdata_all IS NOT INITIAL.
      lo_strucdescr  ?= cl_abap_typedescr=>describe_by_data( ls_valuationdata ).
      MOVE-CORRESPONDING ls_valuationdata_all TO ls_valuationdata.
      LOOP AT lo_strucdescr->components ASSIGNING <fs_components>.
        ASSIGN COMPONENT <fs_components>-name OF STRUCTURE ls_valuationdata TO <fs_value>.
        IF <fs_value> IS ASSIGNED AND <fs_value> IS NOT INITIAL.
          ASSIGN COMPONENT <fs_components>-name OF STRUCTURE ls_valuationdatax TO <fs_value_x>.
          IF <fs_value_x> IS ASSIGNED .
            <fs_value_x> = abap_true.
            UNASSIGN <fs_value_x> .
          ENDIF.
          UNASSIGN <fs_value>.
        ENDIF.
      ENDLOOP.

      ls_valuationdata-val_area = p_vkorg.
      ls_valuationdatax-val_area = p_vkorg.
    ENDIF.


* Tax Classification
*    LOOP AT lt_taxclassifications_all ASSIGNING FIELD-SYMBOL(<fs_taxclassifications_all>) WHERE taxclass_1 = 'MWST'.
    APPEND INITIAL LINE TO lt_taxclassification ASSIGNING FIELD-SYMBOL(<fs_taxclassification>).
    <fs_taxclassification>-depcountry = 'CN'.
    <fs_taxclassification>-depcountry_iso = 'CN'.
    <fs_taxclassification>-tax_type_1 = 'MWST'.
    <fs_taxclassification>-taxclass_1 = 1.


    LOOP AT lt_materialdescription_all ASSIGNING FIELD-SYMBOL(<fs_materialdescription_all>).
      APPEND INITIAL LINE TO lt_materialdescription ASSIGNING FIELD-SYMBOL(<fs_materialdescription>).
      <fs_materialdescription>-langu = <fs_materialdescription_all>-langu.
      <fs_materialdescription>-matl_desc = <fs_materialdescription_all>-matl_desc.
    ENDLOOP.

    CALL FUNCTION 'BAPI_MATERIAL_SAVEDATA'
      EXPORTING
        headdata            = ls_headdata
        clientdata          = ls_clientdata
        clientdatax         = ls_clientdatax
        plantdata           = ls_plantdata
        plantdatax          = ls_plantdatax
        salesdata           = ls_salesdata
        salesdatax          = ls_salesdatax
        valuationdata       = ls_valuationdata
        valuationdatax      = ls_valuationdatax
      IMPORTING
        return              = ls_return
      TABLES
        taxclassifications  = lt_taxclassification
        materialdescription = lt_materialdescription
        returnmessages      = lt_messages.
    IF ls_return-type CA 'EA'.
      LOOP AT lt_messages ASSIGNING FIELD-SYMBOL(<fs_messages>).
        WRITE <fs_messages>-type .
        WRITE <fs_messages>-id .
        WRITE <fs_messages>-number.
        WRITE <fs_messages>-message.
        WRITE <fs_messages>-log_no.
        WRITE <fs_messages>-log_msg_no.
        WRITE <fs_messages>-message_v1.
        WRITE <fs_messages>-message_v2.
        WRITE <fs_messages>-message_v3.
        WRITE <fs_messages>-message_v4.
        WRITE <fs_messages>-parameter.
        WRITE <fs_messages>-row.
        WRITE <fs_messages>-field.
        WRITE <fs_messages>-system.
        WRITE /.
      ENDLOOP.
    ELSE.
      WRITE ls_return-type .
      WRITE ls_return-id .
      WRITE ls_return-number.
      WRITE ls_return-message.
      WRITE ls_return-log_no.
      WRITE ls_return-log_msg_no.
      WRITE ls_return-message_v1.
      WRITE ls_return-message_v2.
      WRITE ls_return-message_v3.
      WRITE ls_return-message_v4.
      WRITE ls_return-parameter.
      WRITE ls_return-row.
      WRITE ls_return-field.
      WRITE ls_return-system.
      WRITE /.
*        message update success
      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
        EXPORTING
          wait = 'X'.
    ENDIF.
  ENDLOOP.
