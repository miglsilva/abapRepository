*&---------------------------------------------------------------------*
*&  Include           ZLER_DELIVERY_ITEM_F01
*&---------------------------------------------------------------------*
* ---------------------------------------------------------------------*
*       FORM main
* ---------------------------------------------------------------------*
form entry using return_code type sy-subrc
                 us_screen   type xflag.

  clear return_code.

  return_code = lcl_del_item=>entry( is_nast   = nast
                                     is_tnapr  = tnapr
                                     i_preview = us_screen ).

endform.                    "main
