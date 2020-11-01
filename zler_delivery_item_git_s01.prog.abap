*&---------------------------------------------------------------------*
*&  Include           ZLER_DELIVERY_ITEM_S01
*&---------------------------------------------------------------------*
parameters: p_kappl type nast-kappl,
            p_objky type nast-objky,
            p_kschl type nast-kschl,
            p_spras type nast-spras.

select-options: s_erdat for nast-erdat.

parameters: p_prv as checkbox default 'X'.
