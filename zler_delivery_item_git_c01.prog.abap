*&---------------------------------------------------------------------*
*&  Include           ZLER_DELIVERY_ITEM_C01
*&---------------------------------------------------------------------*

class lcl_del_item definition final.

  public section.

    class-methods: entry importing is_nast        type nast
                                   is_tnapr       type tnapr
                                   i_preview      type boole_d
                         returning value(e_subrc) type sy-subrc.


  private section.

    constants: begin of _wc_data,
                 ref_doc_type          type vbfa-vbtyp_n             value 'C',
                 spras_de              type sy-langu                 value 'D',
                 tdobject_material     type stxh-tdobject            value 'MATERIAL',
                 tdid_grun             type stxh-tdid                value 'GRUN',
                 tdid_prue             type stxh-tdid                value 'PRUE',
                 objecttable_mara      type bapi1003_key-objecttable value 'MARA',
                 classtype_001         type bapi1003_key-classtype   value '001',
                 char_type_internal    type cabn-atnam               value 'ZDAG_TYPI',
                 confirmed_status      type tj02t-txt04              value 'CNF',
                 distribution_list(30) value 'KONE_CERTIFICATES',
                 dist_list_key(30)     value 'DLINAM',
                 type_raw              type so_obj_tp                value 'RAW',
                 type_pdf              type so_obj_tp                value 'PDF',
                 extension_pdf(4)      value '.pdf',
                 conf_cable_length     type atwrt                   value 'ZH_LENGTH',
               end of _wc_data.

    class-data: begin of _ws_data,
                  begin of s_message,
                    s_nast  type nast,
                    s_tnapr type tnapr,
                  end of s_message,
                  begin of s_print_parameters,
                    preview          type boole_d,
                    s_toa_dara       type toa_dara,
                    s_arc_params     type arc_params,
                    s_composer_param type ssfcompop,
                    s_control_param  type ssfctrlop,
                    s_recipient      type swotobjid,
                    s_sender         type swotobjid,
                    s_addr_key       type addr_key,
                  end of s_print_parameters,
                  s_print_data type zcl_le_print_delivery_helper=>ty_s_print_delivery_item,
                end of _ws_data.

    class-methods: _protocol_update,
      _get_data             returning value(e_subrc) type sy-subrc,
      _set_print_parameters importing i_preview      type boole_d
                            returning value(e_subrc) type sy-subrc,
      _print                returning value(e_subrc) type sy-subrc,
      _get_sales_order_data importing i_vbeln type vbap-vbeln
                                      i_posnr type vbap-posnr,
      _convert_quantity     importing i_string       type string
                            returning value(r_value) type menge_d,
      _email                importing i_fm_name      type rs38l_fnam
                            returning value(e_subrc) type sy-subrc,
      _get_material_characteristics,
      _get_bom_info,
      _get_address_data,
      _get_additional_data,
      _get_texts,
      _clear,
      _get_batch_from_goodsmvt.


endclass.

class lcl_del_item implementation.

  method: entry.

    _clear( ).

    _ws_data-s_message-s_nast           = is_nast.
    _ws_data-s_message-s_tnapr          = is_tnapr.
    _ws_data-s_print_parameters-preview = i_preview.
    _ws_data-s_print_data-vbeln         = _ws_data-s_message-s_nast-objky(10).
    _ws_data-s_print_data-posnr         = _ws_data-s_message-s_nast-objky+10(6).

    e_subrc = _get_data( ).
    if e_subrc is initial.
      e_subrc = _set_print_parameters( i_preview ).
      if e_subrc is initial.
        e_subrc = _print( ).
      endif.
    endif.

  endmethod.

  method: _set_print_parameters.

    data: ls_itcpo type itcpo,
          l_repid  type sy-repid,
          l_device type tddevice.


    l_repid = sy-repid.

    call function 'WFMC_PREPARE_SMART_FORM'
      exporting
        pi_nast       = _ws_data-s_message-s_nast
        pi_addr_key   = _ws_data-s_print_parameters-s_addr_key
        pi_repid      = l_repid
        pi_screen     = i_preview
      importing
        pe_returncode = e_subrc
        pe_itcpo      = ls_itcpo
        pe_device     = l_device
        pe_recipient  = _ws_data-s_print_parameters-s_recipient
        pe_sender     = _ws_data-s_print_parameters-s_sender.
    if e_subrc is initial.
      move-corresponding ls_itcpo to _ws_data-s_print_parameters-s_composer_param.
      _ws_data-s_print_parameters-s_control_param-device    = l_device.
      _ws_data-s_print_parameters-s_control_param-no_dialog = abap_true.
      _ws_data-s_print_parameters-s_control_param-preview   = _ws_data-s_print_parameters-preview.
      _ws_data-s_print_parameters-s_control_param-getotf    = ls_itcpo-tdgetotf.
      _ws_data-s_print_parameters-s_control_param-langu     = _ws_data-s_message-s_nast-spras.
    endif.

  endmethod.

  method: _get_data.

    data: ls_delivery_key       type leshp_delivery_key,
          ls_print_data_to_read type ledlv_print_data_to_read,
          ls_dlv_delnote        type ledlv_delnote,
          l_lwedt               type mch1-lwedt.


    ls_delivery_key-vbeln                 = _ws_data-s_print_data-vbeln.

    ls_print_data_to_read-hd_gen          = abap_true.
    ls_print_data_to_read-hd_adr          = abap_true.
    ls_print_data_to_read-hd_org          = abap_true.
    ls_print_data_to_read-hd_org_adr      = abap_true.
    ls_print_data_to_read-it_gen          = abap_true.
    ls_print_data_to_read-it_gen_descript = abap_true.
    ls_print_data_to_read-it_org          = abap_true.
    ls_print_data_to_read-it_org_descript = abap_true.
    ls_print_data_to_read-it_ref          = abap_true.
    ls_print_data_to_read-it_reford       = abap_true.
    ls_print_data_to_read-it_sched        = abap_true.

    call function 'LE_SHP_DLV_OUTP_READ_PRTDATA'
      exporting
        is_delivery_key       = ls_delivery_key
        is_print_data_to_read = ls_print_data_to_read
        if_parvw              = _ws_data-s_message-s_nast-parvw
        if_parnr              = _ws_data-s_message-s_nast-parnr
        if_language           = _ws_data-s_message-s_nast-spras
      importing
        es_dlv_delnote        = ls_dlv_delnote
      exceptions
        records_not_found     = 1
        records_not_requested = 2
        others                = 3.
    if not sy-subrc is initial.
      e_subrc = sy-subrc.
      _protocol_update( ).
    else.
      _ws_data-s_print_data-s_header-vkorg_adr = ls_dlv_delnote-hd_org-salesorg_adr.

      read table ls_dlv_delnote-hd_adr assigning field-symbol(<ls_hd_adr>) with key deliv_numb = _ws_data-s_print_data-vbeln
                                                                                    partn_role = _ws_data-s_message-s_nast-parvw.
      if sy-subrc is initial and <ls_hd_adr> is assigned.
        _ws_data-s_print_parameters-s_addr_key-addrnumber = <ls_hd_adr>-addr_no.
        _ws_data-s_print_parameters-s_addr_key-persnumber = <ls_hd_adr>-person_numb.
        _ws_data-s_print_parameters-s_addr_key-addr_type  = <ls_hd_adr>-address_type.
      endif.

      read table ls_dlv_delnote-it_gen assigning field-symbol(<ls_it_gen>) with key deliv_numb = _ws_data-s_print_data-vbeln
                                                                                    itm_number = _ws_data-s_print_data-posnr.
      if sy-subrc is initial and <ls_it_gen> is assigned.
        _ws_data-s_print_data-s_item-matnr = <ls_it_gen>-material.

        read table ls_dlv_delnote-it_ref assigning field-symbol(<ls_it_ref>) with key deliv_numb   = _ws_data-s_print_data-vbeln
                                                                                      itm_number   = _ws_data-s_print_data-posnr
                                                                                      ref_doc_type = _wc_data-ref_doc_type.
        if sy-subrc is initial and <ls_it_ref> is assigned.
          _ws_data-s_print_data-s_header-vgbel = <ls_it_ref>-ref_doc.
          _ws_data-s_print_data-s_header-vgpos = <ls_it_ref>-ref_doc_it.

          _get_sales_order_data( i_vbeln = <ls_it_ref>-ref_doc i_posnr = <ls_it_ref>-ref_doc_it ).

        endif.

        if _ws_data-s_print_data-s_item-prod_werks is initial.
          read table ls_dlv_delnote-it_org assigning field-symbol(<ls_it_org>) with key deliv_numb = _ws_data-s_print_data-vbeln
                                                                                        itm_number = _ws_data-s_print_data-posnr.
          if sy-subrc is initial and <ls_it_org> is assigned.
            _ws_data-s_print_data-s_item-prod_werks = <ls_it_org>-plant.
          endif.
        endif.

        if not _ws_data-s_print_data-s_item-prod_werks is initial.
          select single adrnr from t001w into _ws_data-s_print_data-s_item-prod_werks_adr where werks = _ws_data-s_print_data-s_item-prod_werks.
        endif.

        if _ws_data-s_print_data-s_item-cable_matnr is initial.
          _ws_data-s_print_data-s_item-cable_matnr = _ws_data-s_print_data-s_item-matnr.
        endif.

        if not _ws_data-s_print_data-s_item-cable_charg is initial.
          _ws_data-s_print_data-s_item-charg_list = _ws_data-s_print_data-s_item-cable_charg.
        else.
          loop at ls_dlv_delnote-it_gen assigning <ls_it_gen> where ( itm_number = _ws_data-s_print_data-posnr or uecha = _ws_data-s_print_data-posnr )
                                                                and not batch is initial.
            if _ws_data-s_print_data-s_item-charg_list is initial.
              _ws_data-s_print_data-s_item-charg_list = <ls_it_gen>-batch.
            else.
              concatenate _ws_data-s_print_data-s_item-charg_list '/' <ls_it_gen>-batch into _ws_data-s_print_data-s_item-charg_list separated by space.
            endif.
            select single lwedt into l_lwedt from mch1 where matnr = <ls_it_gen>-material and charg = <ls_it_gen>-batch.
            if sy-subrc is initial and not l_lwedt is initial.
              if _ws_data-s_print_data-s_item-confirmation_date is initial.
                _ws_data-s_print_data-s_item-confirmation_date = l_lwedt.
              elseif _ws_data-s_print_data-s_item-confirmation_date > l_lwedt.
                _ws_data-s_print_data-s_item-confirmation_date = l_lwedt.
              endif.
            endif.
            _ws_data-s_print_data-s_item-cable_menge = _ws_data-s_print_data-s_item-cable_menge + <ls_it_gen>-dlv_qty.
            _ws_data-s_print_data-s_item-cable_meins = <ls_it_gen>-sales_unit.
          endloop.
          if sy-subrc <> 0. "get batch number from material
            _get_batch_from_goodsmvt( ).
          endif.
        endif.


        _get_material_characteristics( ).

*        _get_bom_info( ).

        _get_address_data( ).

        _get_texts( ).

        _get_additional_data( ).

      endif.

    endif.

  endmethod.

  method: _get_texts.

    data: begin of ls_text,
            tdobject type stxh-tdobject,
            tdspras  type stxh-tdspras,
            tdid     type stxh-tdid,
            tdname   type stxh-tdname,
          end of ls_text.

    select single maktx into _ws_data-s_print_data-s_item-cable_maktx from makt
                       where matnr = _ws_data-s_print_data-s_item-cable_matnr
                         and spras = _ws_data-s_message-s_nast-spras.
    if not sy-subrc is initial.
      select single maktx into _ws_data-s_print_data-s_item-cable_maktx from makt
                         where matnr = _ws_data-s_print_data-s_item-cable_matnr
                           and spras = _wc_data-spras_de.
    endif.

    ls_text-tdobject = _wc_data-tdobject_material.
    ls_text-tdname   = _ws_data-s_print_data-s_item-cable_matnr.
    ls_text-tdid     = _wc_data-tdid_grun.
    ls_text-tdspras  = _ws_data-s_message-s_nast-spras.
    select single tdname as name tdobject as object tdid as id tdspras as spras
            into corresponding fields of _ws_data-s_print_data-s_item-s_basic_text
            from stxh where tdobject = ls_text-tdobject
                        and tdname   = ls_text-tdname
                        and tdid     = ls_text-tdid
                        and tdspras  = ls_text-tdspras.
    if not sy-subrc is initial.
      ls_text-tdspras  = _wc_data-spras_de.
      select single tdname as name tdobject as object tdid as id tdspras as spras
              into corresponding fields of _ws_data-s_print_data-s_item-s_basic_text
              from stxh where tdobject = ls_text-tdobject
                          and tdname   = ls_text-tdname
                          and tdid     = ls_text-tdid
                          and tdspras  = ls_text-tdspras.
    endif.

    ls_text-tdobject = _wc_data-tdobject_material.
    ls_text-tdname   = _ws_data-s_print_data-s_item-cable_matnr.
    ls_text-tdid     = _wc_data-tdid_prue.
    ls_text-tdspras  = _ws_data-s_message-s_nast-spras.
    select single tdname as name tdobject as object tdid as id tdspras as spras
            into corresponding fields of _ws_data-s_print_data-s_item-s_inspection_text
            from stxh where tdobject = ls_text-tdobject
                        and tdname   = ls_text-tdname
                        and tdid     = ls_text-tdid
                        and tdspras  = ls_text-tdspras.
    if not sy-subrc is initial.
      ls_text-tdspras  = _wc_data-spras_de.
      select single tdname as name tdobject as object tdid as id tdspras as spras
              into corresponding fields of _ws_data-s_print_data-s_item-s_inspection_text
              from stxh where tdobject = ls_text-tdobject
                          and tdname   = ls_text-tdname
                          and tdid     = ls_text-tdid
                          and tdspras  = ls_text-tdspras.
    endif.

  endmethod.

  method: _get_additional_data.

    call function 'CONVERSION_EXIT_LDATE_OUTPUT'
      exporting
        input  = _ws_data-s_print_data-s_item-confirmation_date
      importing
        output = _ws_data-s_print_data-s_item-date_long.
    shift _ws_data-s_print_data-s_item-date_long left deleting leading '0'.
    if strlen( _ws_data-s_print_data-s_item-date_long ) > 2.
      case _ws_data-s_print_data-s_item-date_long(2).
        when '1.'.   replace '.' into _ws_data-s_print_data-s_item-date_long with text-001.
        when '2.'.   replace '.' into _ws_data-s_print_data-s_item-date_long with text-002.
        when '3.'.   replace '.' into _ws_data-s_print_data-s_item-date_long with text-003.
        when others. replace '.' into _ws_data-s_print_data-s_item-date_long with text-004.
      endcase.
    endif.

    select single mseht from t006a into _ws_data-s_print_data-s_item-cable_mseht where spras = _ws_data-s_message-s_nast-spras
                                                                                   and msehi = _ws_data-s_print_data-s_item-cable_meins.
    if not sy-subrc is initial.
      select single mseht from t006a into _ws_data-s_print_data-s_item-cable_mseht where spras = _wc_data-spras_de
                                                                                     and msehi = _ws_data-s_print_data-s_item-cable_meins.
    endif.

  endmethod.

  method: _get_address_data.

    data: ls_addresses type szadr_addr1_complete.


    call function 'ADDR_GET_COMPLETE'
      exporting
        addrnumber              = _ws_data-s_print_data-s_item-prod_werks_adr
      importing
        addr1_complete          = ls_addresses
      exceptions
        parameter_error         = 1
        address_not_exist       = 2
        internal_error          = 3
        wrong_access_to_archive = 4
        address_blocked         = 5
        others                  = 6.
    if sy-subrc is initial.
      loop at ls_addresses-addr1_tab assigning field-symbol(<ls_addr1>) where data-date_from <= _ws_data-s_message-s_nast-erdat
                                                                          and data-date_to   >= _ws_data-s_message-s_nast-erdat.

        _ws_data-s_print_data-s_item-prod_werks_city = <ls_addr1>-data-city1.
        select single landx from t005t into _ws_data-s_print_data-s_item-prod_werks_ctr
                                      where t005t~land1 = <ls_addr1>-data-country
                                        and t005t~spras = _ws_data-s_message-s_nast-spras.
        _ws_data-s_print_data-s_item-prod_werks_dsc = <ls_addr1>-data-name1.
        exit.
      endloop.
    endif.

  endmethod.

  method: _get_material_characteristics.

    data: lt_return type table of bapiret2,
          lt_list   type table of bapi1003_alloc_list,
          lt_char   type table of bapi1003_alloc_values_char,
          ls_key    type bapi1003_key.


    ls_key-object      = _ws_data-s_print_data-s_item-cable_matnr.
    ls_key-objecttable = _wc_data-objecttable_mara.
    ls_key-classtype   = _wc_data-classtype_001.
    call function 'BAPI_OBJCL_GETCLASSES'
      exporting
        objectkey_imp   = ls_key-object
        objecttable_imp = ls_key-objecttable
        classtype_imp   = ls_key-classtype
        read_valuations = abap_true
      tables
        alloclist       = lt_list
        allocvalueschar = lt_char
        return          = lt_return.
    try.
        _ws_data-s_print_data-s_item-s_chars-type_internal = lt_char[ charact = _wc_data-char_type_internal ]-value_char.
      catch cx_sy_itab_line_not_found.
        clear: _ws_data-s_print_data-s_item-s_chars-type_internal.
    endtry.

  endmethod.

  method: _get_sales_order_data.

    data: lt_components type zcl_harnessing_core=>zif_harnessing_core~ty_components_attr_t,
          l_objnr       type aufk-objnr,
          lt_config     type standard table of conf_out.

    data(lo_so_item) = new zrucl_so_item_info( iv_read_vbak_from_db = abap_true
                                               iv_read_vbap_from_db = abap_true
                                               iv_vbeln             = i_vbeln
                                               iv_posnr             = i_posnr ).
    if lo_so_item is bound.
      lo_so_item->get_cust_po_info( importing ev_bstkd = _ws_data-s_print_data-s_header-bstkd ).
      lo_so_item->get_first_prod_order( exporting iv_spras = _ws_data-s_message-s_nast-spras
                                        importing ev_first_prod_order = _ws_data-s_print_data-s_item-aufnr ).
      if not _ws_data-s_print_data-s_item-aufnr is initial.
        select single werks objnr from aufk into (_ws_data-s_print_data-s_item-prod_werks,l_objnr) where aufnr = _ws_data-s_print_data-s_item-aufnr.
        select matnr werks from resb into corresponding fields of table lt_components where rsnum = ( select rsnum from afko where aufnr = _ws_data-s_print_data-s_item-aufnr ).
        if not l_objnr is initial.
          select single jcds~udate into _ws_data-s_print_data-s_item-confirmation_date
                                   from jcds join tj02t on tj02t~istat = jcds~stat
                                  where jcds~objnr  = l_objnr
                                    and jcds~inact  = ' '
                                    and tj02t~txt04 = _wc_data-confirmed_status.
        endif.
      endif.

*      lo_so_item->get_simulated_bom_v1( exporting iv_aufnr = _ws_data-s_print_data-s_item-aufnr ).
*
*      loop at lo_so_item->gt_bom_used assigning field-symbol(<ls_bom_used>).
*        append value #( matnr = <ls_bom_used>-idnrk werks = <ls_bom_used>-werks ) to lt_components.
*      endloop.
      if not lt_components is initial.
        zcl_harnessing_core=>zif_harnessing_core~material_cable_plug_attr_get( exporting iv_cable_dispo_xfilter = abap_true
                                                                               changing  ct_mat_attr            = lt_components ).
        loop at lt_components assigning field-symbol(<ls_component>) where cable = abap_true.
          _ws_data-s_print_data-s_item-cable_matnr = <ls_component>-matnr.
          select single resb~charg resb~bdmng resb~meins into (_ws_data-s_print_data-s_item-cable_charg, _ws_data-s_print_data-s_item-cable_menge, _ws_data-s_print_data-s_item-cable_meins)
                   from resb where rsnum = ( select rsnum from afko where aufnr = _ws_data-s_print_data-s_item-aufnr )
                               and matnr = <ls_component>-matnr.

        endloop.
      endif.

      call function 'VC_I_GET_CONFIGURATION_IBASE'
        exporting
          instance           = lo_so_item->gs_vbap-cuobj
        tables
          configuration      = lt_config
        exceptions
          instance_not_found = 1
          others             = 2.

      read table lt_config into data(ls_config)  with key atnam = _wc_data-conf_cable_length.
      if sy-subrc = 0.
        _ws_data-s_print_data-s_item-cable_conf_length = ls_config-atwrt.
      endif.

    endif.

  endmethod.

  method: _convert_quantity.

    /gib/cl_dc_conversion=>move_char_to_p( exporting if_value = conv #( i_string )
                                           importing cf_value = r_value ).

  endmethod.

  method: _get_bom_info.

    data: lt_components type zcl_harnessing_core=>zif_harnessing_core~ty_components_attr_t,
          lt_stpo       type table of stpo_api02,
          begin of ls_bom,
            matnr type mara-matnr,
            menge type stpo_api02-comp_qty,
            meins type stpo_api02-comp_unit,
          end of ls_bom,
          lt_bom    like table of ls_bom,
          l_matnr40 type csap_mbom-matnr.


    if _ws_data-s_print_data-s_item-cable_matnr is initial.
      call function 'CONVERSION_EXIT_MATN2_OUTPUT'
        exporting
          input  = _ws_data-s_print_data-s_item-matnr
        importing
          output = l_matnr40.

      call function 'CSAP_MAT_BOM_READ'
        exporting
          material  = l_matnr40
          plant     = _ws_data-s_print_data-s_item-prod_werks
          bom_usage = '1'
        tables
          t_stpo    = lt_stpo
        exceptions
          error     = 1
          others    = 2.
      if sy-subrc is initial and not lt_stpo is initial.
        loop at lt_stpo assigning field-symbol(<ls_stpo>).
          clear: ls_bom.
          call function 'CONVERSION_EXIT_MATN2_INPUT'
            exporting
              input            = <ls_stpo>-component
            importing
              output           = ls_bom-matnr
            exceptions
              number_not_found = 1
              length_error     = 2
              others           = 3.
          if sy-subrc is initial.
            append value #( matnr = ls_bom-matnr menge = _convert_quantity( conv #( <ls_stpo>-comp_qty ) ) meins = <ls_stpo>-comp_unit ) to lt_bom.
            append value #( matnr = ls_bom-matnr werks = _ws_data-s_print_data-s_item-prod_werks ) to lt_components.
          endif.
        endloop.

        zcl_harnessing_core=>zif_harnessing_core~material_cable_plug_attr_get( exporting iv_cable_dispo_xfilter = abap_true
                                                                               changing  ct_mat_attr            = lt_components ).
        loop at lt_components assigning field-symbol(<ls_component>) where cable = abap_true.
          _ws_data-s_print_data-s_item-cable_matnr = <ls_component>-matnr.
          read table lt_bom assigning field-symbol(<ls_bom>) with key matnr = <ls_component>-matnr.
          if sy-subrc is initial and <ls_bom> is assigned.
            _ws_data-s_print_data-s_item-cable_menge = <ls_bom>-menge.
            _ws_data-s_print_data-s_item-cable_meins = <ls_bom>-meins.
          endif.
*          _ws_data-s_print_data-s_item-cable_menge = <ls_component>-menge.
        endloop.

      endif.

    endif.

  endmethod.

  method: _clear.

    clear: _ws_data.

  endmethod.

  method: _protocol_update.

    call function 'NAST_PROTOCOL_UPDATE'
      exporting
        msg_arbgb              = syst-msgid
        msg_nr                 = syst-msgno
        msg_ty                 = syst-msgty
        msg_v1                 = syst-msgv1
        msg_v2                 = syst-msgv2
        msg_v3                 = syst-msgv3
        msg_v4                 = syst-msgv4
      exceptions
        message_type_not_valid = 1
        no_sy_message          = 2
        others                 = 3.
    if not sy-subrc is initial.
      return.
    endif.

  endmethod.

  method: _print.

    data: l_fm_name type rs38l_fnam.


    call function 'SSF_FUNCTION_MODULE_NAME'
      exporting
        formname           = _ws_data-s_message-s_tnapr-sform
      importing
        fm_name            = l_fm_name
      exceptions
        no_form            = 1
        no_function_module = 2
        others             = 3.
    if not sy-subrc is initial.
      e_subrc = sy-subrc.
      _protocol_update( ).

    else.

      call function l_fm_name
        exporting
          archive_index      = _ws_data-s_print_parameters-s_toa_dara
          archive_parameters = _ws_data-s_print_parameters-s_arc_params
          control_parameters = _ws_data-s_print_parameters-s_control_param
          mail_recipient     = _ws_data-s_print_parameters-s_recipient
          mail_sender        = _ws_data-s_print_parameters-s_sender
          output_options     = _ws_data-s_print_parameters-s_composer_param
          user_settings      = ' '
          is_nast            = _ws_data-s_message-s_nast
          is_data            = _ws_data-s_print_data
        exceptions
          formatting_error   = 1
          internal_error     = 2
          send_error         = 3
          user_canceled      = 4
          others             = 5.
      if not sy-subrc is initial.
        e_subrc = sy-subrc.
        _protocol_update( ).
      else.
        if _ws_data-s_print_parameters-preview is initial.
          e_subrc = _email( l_fm_name ).
        endif.
      endif.
    endif.

  endmethod.

  method: _email.

    data: ls_output_info type ssfcrescl,
          lt_lines       type table of tline,
          lt_values      type zif_harnessing_core=>ty_sel_par_t,
          l_pdf_size     type i,
          l_pdf_file     type xstring,
          l_subject      type so_obj_des.


    _ws_data-s_print_parameters-s_control_param-getotf = abap_true.
    call function i_fm_name
      exporting
        archive_index      = _ws_data-s_print_parameters-s_toa_dara
        archive_parameters = _ws_data-s_print_parameters-s_arc_params
        control_parameters = _ws_data-s_print_parameters-s_control_param
        mail_recipient     = _ws_data-s_print_parameters-s_recipient
        mail_sender        = _ws_data-s_print_parameters-s_sender
        output_options     = _ws_data-s_print_parameters-s_composer_param
        user_settings      = ' '
        is_nast            = _ws_data-s_message-s_nast
        is_data            = _ws_data-s_print_data
      importing
        job_output_info    = ls_output_info
      exceptions
        formatting_error   = 1
        internal_error     = 2
        send_error         = 3
        user_canceled      = 4
        others             = 5.
    if not sy-subrc is initial.
      e_subrc = sy-subrc.
    else.
      call function 'CONVERT_OTF'
        exporting
          format                = 'PDF'
          max_linewidth         = 132
        importing
          bin_filesize          = l_pdf_size
          bin_file              = l_pdf_file
        tables
          otf                   = ls_output_info-otfdata
          lines                 = lt_lines
        exceptions
          err_max_linewidth     = 1
          err_format            = 2
          err_conv_not_possible = 3
          err_bad_otf           = 4
          others                = 5.
      if not sy-subrc is initial.
        e_subrc = sy-subrc.
      else.
        try.
            data(lo_request) = cl_bcs=>create_persistent( ).
          catch cx_send_req_bcs.
        endtry.
        if lo_request is bound.
          zcl_harnessing_core=>zif_harnessing_core~constant_values_get( exporting iv_constant_id    = conv #( _wc_data-distribution_list )
                                                                                  iv_vakey1         = conv #( _wc_data-dist_list_key )
                                                                                  iv_type           = 'S'
                                                                        changing  ct_sel_par_values = lt_values ).
          loop at lt_values assigning field-symbol(<ls_value>).
            try.
                data(lo_distribution_list) = cl_distributionlist_bcs=>getu_persistent( i_dliname = conv #( <ls_value>-low )
                                                                                       i_private = abap_false ).
              catch cx_address_bcs.
            endtry.
            if lo_distribution_list is bound.
              try.
                  lo_request->add_recipient( i_recipient = lo_distribution_list
                                             i_express   = abap_true ).
                catch cx_send_req_bcs.
              endtry.
            endif.
          endloop.
          select single vtext from t685t into l_subject where spras = _ws_data-s_message-s_nast-spras
                                                          and kvewe = 'B'
                                                          and kappl = _ws_data-s_message-s_nast-kappl
                                                          and kschl = _ws_data-s_message-s_nast-kschl.
          data(l_print_id) = _ws_data-s_print_data-vbeln && '/' && _ws_data-s_print_data-posnr.
          concatenate l_subject l_print_id into l_subject separated by space.
          try.
              data(lo_document) = cl_document_bcs=>create_document( i_type    = _wc_data-type_raw
                                                                    i_subject = l_subject ).
            catch cx_document_bcs.
          endtry.
          if lo_document is bound.
            try.
                lo_document->add_attachment( i_attachment_type    = _wc_data-type_pdf
                                             i_att_content_hex    =  cl_bcs_convert=>xstring_to_solix( l_pdf_file )
                                             i_attachment_subject =  conv #( l_subject && _wc_data-extension_pdf ) ).
              catch cx_document_bcs.
            endtry.
            try.
                lo_request->set_document( lo_document ).
              catch cx_send_req_bcs.
            endtry.
          endif.
          try.
              lo_request->send( ).
            catch cx_send_req_bcs.
          endtry.
        endif.
      endif.

    endif.

  endmethod.
  method _get_batch_from_goodsmvt.
    check _ws_data-s_print_data-s_item-charg_list is initial.

    data: begin of ls_resb,
            rsnum type  resb-rsnum,
            rspos type  resb-rspos,
            werks type  resb-werks,
            lgort type  resb-lgort,
            bwart type  resb-bwart,
          end of ls_resb,
          lt_resb            like table of ls_resb,
          ltr_mat            type table of bapi2017_gm_material_ra,
          ltr_plant          type table of bapi2017_gm_plant_ra,
          ltr_stge_loc       type table of bapi2017_gm_stge_loc_ra,
          ltr_move_type      type table of bapi2017_gm_move_type_ra,
          lt_goodsmvt_items  type table of bapi2017_gm_item_show,
          lt_goodsmvt_header type table of bapi2017_gm_head_02,
          lt_return          type table of bapiret2.

    select distinct r~rsnum r~rspos r~werks r~lgort r~bwart
        into table lt_resb
        from caufv as c inner join resb as r on r~rsnum = c~rsnum
      where c~kdauf   = _ws_data-s_print_data-s_header-vgbel
        and c~kdpos   = _ws_data-s_print_data-s_header-vgpos
        and r~matnr   = _ws_data-s_print_data-s_item-cable_matnr.

    loop at lt_resb into ls_resb.
      append value #( sign = 'I' option = 'EQ' low = ls_resb-werks  ) to ltr_plant.
      append value #( sign = 'I' option = 'EQ' low = ls_resb-bwart  ) to ltr_move_type.
    endloop.
    if sy-subrc = 0.
      append value #( sign = 'I' option = 'EQ' low =  _ws_data-s_print_data-s_item-cable_matnr ) to ltr_mat.
      call function 'BAPI_GOODSMVT_GETITEMS'
        tables
          material_ra     = ltr_mat
          plant_ra        = ltr_plant
          move_type_ra    = ltr_move_type
          goodsmvt_header = lt_goodsmvt_header
          goodsmvt_items  = lt_goodsmvt_items
          return          = lt_return.
      if not line_exists( lt_return[ type = 'E' ] ) .
        loop at lt_resb into ls_resb .
          loop at lt_goodsmvt_items assigning field-symbol(<ls_mvt_itens>)
            where batch is not initial
            and  reserv_no = ls_resb-rsnum
            and res_item =  ls_resb-rspos.

            shift <ls_mvt_itens>-batch  left deleting leading '0'.
            if _ws_data-s_print_data-s_item-charg_list is initial.
              _ws_data-s_print_data-s_item-charg_list = <ls_mvt_itens>-batch.
            else.
              concatenate _ws_data-s_print_data-s_item-charg_list '/' <ls_mvt_itens>-batch into _ws_data-s_print_data-s_item-charg_list separated by space.
            endif.
          endloop.
        endloop.
      endif.

    endif.
  endmethod.
endclass.
