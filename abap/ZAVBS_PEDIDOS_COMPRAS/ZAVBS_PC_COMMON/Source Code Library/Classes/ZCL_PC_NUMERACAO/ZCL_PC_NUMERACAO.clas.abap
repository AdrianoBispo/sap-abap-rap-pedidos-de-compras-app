"! <p class="shorttext synchronized">Pedidos de Compras - Numeração (Number Range)</p>
"! Objeto de numeração ZPC_NR (domínio de tamanho NUMC 10):
"!   intervalo 01 -> NumeroPedido
"!   intervalo 02 -> sequencial do SKU
"! Os intervalos são criados pela classe ZCL_PC_SETUP.
"! Constantes, tipos e métodos públicos: interface ZIF_PC_NUMERACAO.
CLASS zcl_pc_numeracao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_pc_numeracao.

    ALIASES proximo_numero_pedido FOR zif_pc_numeracao~proximo_numero_pedido.
    ALIASES gerar_sku FOR zif_pc_numeracao~gerar_sku.
    ALIASES prefixo_categoria FOR zif_pc_numeracao~prefixo_categoria.

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


  METHOD zif_pc_numeracao~proximo_numero_pedido.
    DATA(lv_numero) = proximo_numero( zif_pc_constants=>c_numeracao-intervalo_pedido ).
    rv_numero = |{ lv_numero WIDTH = 10 ALIGN = RIGHT PAD = '0' }|.
  ENDMETHOD.


  METHOD zif_pc_numeracao~gerar_sku.
    DATA(lv_numero) = proximo_numero( zif_pc_constants=>c_numeracao-intervalo_sku )
                      - CONV int8( zif_pc_constants=>c_numeracao-sku_de ).

    rv_sku = |SKU-{ prefixo_categoria( iv_categoria ) }-{ lv_numero WIDTH = 10 ALIGN = RIGHT PAD = '0' }|.
  ENDMETHOD.


  METHOD zif_pc_numeracao~prefixo_categoria.
    rv_prefixo = to_upper( condense( iv_categoria ) ).
    IF strlen( rv_prefixo ) < 3.
      rv_prefixo = |{ rv_prefixo WIDTH = 3 PAD = 'X' }|.
    ENDIF.
    rv_prefixo = substring( val = rv_prefixo off = 0 len = 3 ).
  ENDMETHOD.

ENDCLASS.
