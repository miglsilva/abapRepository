*&---------------------------------------------------------------------*
*&  Include           ZLER_DELIVERY_ITEM_E01
*&---------------------------------------------------------------------*
start-of-selection.

data: l_return_code type sy-subrc.


  select single * from nast into nast where kappl =  p_kappl
                                        and objky =  p_objky
                                        and kschl =  p_kschl
                                        and spras =  p_spras
                                        and erdat in s_erdat.
if sy-subrc is initial.
  select single * from tnapr into tnapr where kschl = nast-kschl
                                          and nacha = nast-nacha
                                          and kappl = nast-kappl.
  if sy-subrc is initial.
    perform entry using l_return_code p_prv.
    if l_return_code is initial.
      commit work.
    endif.
  endif.
endif.
