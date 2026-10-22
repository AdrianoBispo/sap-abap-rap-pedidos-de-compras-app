"! <p class="shorttext synchronized">Pedidos de Compras - Pagamento simulado com cartão</p>
"! Constantes, tipos e métodos públicos de ZCL_PC_PAGAMENTO_SIM, que implementa esta interface.
INTERFACE zif_pc_pagamento_sim PUBLIC.

  TYPES:
    BEGIN OF ty_entrada,
      metodo   TYPE string,
      numero   TYPE string,
      validade TYPE string,
      cvv      TYPE string,
    END OF ty_entrada.

  TYPES:
    BEGIN OF ty_resultado,
      "! abap_false => dados inválidos (erro de entrada, não é recusa)
      dados_validos      TYPE abap_boolean,
      erro               TYPE string,
      status             TYPE zif_pc_constants=>ty_status_pagamento,
      metodo             TYPE zif_pc_constants=>ty_metodo_pagamento,
      bandeira           TYPE string,
      ultimos4           TYPE string,
      cartao_mascarado   TYPE string,
      codigo_autorizacao TYPE string,
      mensagem           TYPE string,
    END OF ty_resultado.

  CLASS-METHODS simular
    IMPORTING is_entrada          TYPE ty_entrada
              iv_data_referencia  TYPE d OPTIONAL
    RETURNING VALUE(rs_resultado) TYPE ty_resultado.

ENDINTERFACE.