"! <p class="shorttext synchronized">Pedidos de Compras - Numeração (Number Range)</p>
"! Objeto de numeração ZPC_NR (domínio de tamanho NUMC 10):
"!   intervalo 01 -> NumeroPedido
"!   intervalo 02 -> sequencial do SKU
"! Os intervalos são criados pela classe ZCL_PC_SETUP.
CLASS zcl_pc_numeracao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_numero_pedido TYPE c LENGTH 10.
    TYPES ty_sku           TYPE c LENGTH 21.

    "! Próximo número de pedido, com 10 dígitos (ex.: 0000000001).
    CLASS-METHODS proximo_numero_pedido
      RETURNING VALUE(rv_numero) TYPE ty_numero_pedido
      RAISING   cx_number_ranges.

    "! SKU no formato SKU-<3 letras da categoria>-<10 dígitos>.
    "! Ex.: SKU-ELE-0000000042 (18 caracteres; campo CHAR 21).
    CLASS-METHODS gerar_sku
      IMPORTING iv_categoria  TYPE csequence
      RETURNING VALUE(rv_sku) TYPE ty_sku
      RAISING   cx_number_ranges.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-METHODS proximo_numero
      IMPORTING iv_intervalo     TYPE csequence
      RETURNING VALUE(rv_numero) TYPE int8
      RAISING   cx_number_ranges.
ENDCLASS.



CLASS zcl_pc_numeracao IMPLEMENTATION.

  METHOD proximo_numero.
    cl_numberrange_runtime=>number_get(
      EXPORTING
        nr_range_nr = CONV #( iv_intervalo )
        object      = CONV #( zif_pc_constants=>c_numeracao-objeto )
      IMPORTING
        number      = DATA(lv_numero) ).

    rv_numero = CONV int8( lv_numero ).
  ENDMETHOD.


  METHOD proximo_numero_pedido.
    DATA(lv_numero) = proximo_numero( zif_pc_constants=>c_numeracao-intervalo_pedido ).
    rv_numero = |{ lv_numero WIDTH = 10 ALIGN = RIGHT PAD = '0' }|.
  ENDMETHOD.


  METHOD gerar_sku.
    DATA(lv_numero) = proximo_numero( zif_pc_constants=>c_numeracao-intervalo_sku ).

    DATA(lv_prefixo) = to_upper( condense( iv_categoria ) ).
    IF strlen( lv_prefixo ) < 3.
      lv_prefixo = |{ lv_prefixo WIDTH = 3 PAD = 'X' }|.
    ENDIF.

    rv_sku = |SKU-{ substring( val = lv_prefixo off = 0 len = 3 ) }-{ lv_numero WIDTH = 10 ALIGN = RIGHT PAD = '0' }|.
  ENDMETHOD.

ENDCLASS.
