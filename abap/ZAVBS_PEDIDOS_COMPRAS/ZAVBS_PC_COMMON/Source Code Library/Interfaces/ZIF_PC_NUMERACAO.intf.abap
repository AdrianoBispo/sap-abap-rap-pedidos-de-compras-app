"! <p class="shorttext synchronized">Pedidos de Compras - Numeração (Number Range)</p>
"! Constantes, tipos e métodos públicos de ZCL_PC_NUMERACAO, que implementa esta interface.
INTERFACE zif_pc_numeracao PUBLIC.

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

  "! Prefixo de 3 letras do SKU a partir do código da categoria
  "! (maiúsculas; categoria curta ou vazia é completada com X).
  CLASS-METHODS prefixo_categoria
    IMPORTING iv_categoria     TYPE csequence
    RETURNING VALUE(rv_prefixo) TYPE string.

ENDINTERFACE.