"! <h1>Interface para classe ZCL_PC_PAGAMENTO_SIM</h1>
"! Interface onde é declarada as constantes, tipos e métodos públicos da classe {@link ZCL_PC_PAGAMENTO_SIM}
INTERFACE zif_pc_pagamento_sim PUBLIC.

  TYPES:
    "! Tipos para o parametro de importacao do metodo {@link ZCL_PC_PAGAMENTO_SIM.METH:simular}
    BEGIN OF ty_entrada,
      "! Metodo de pagamento: cartão de crédito ou débito
      metodo   TYPE string,
      "! Número do cartão
      numero   TYPE string,
      "! Data de vencimento do cartão
      validade TYPE string,
      "! Código de 3 digitos do cartão
      cvv      TYPE string,
    END OF ty_entrada.

  TYPES:
    "! Tipos para definir os dados de retorno do método {@link ZCL_PC_PAGAMENTO_SIM.METH:simular}
    BEGIN OF ty_resultado,
      "! Indicador de consistência dos dados de entrada. Se o retorno for <strong>abap_false</strong>
      "! um erro é disparado e a ação de pagamento é cancelada sem gerar recusa.
      dados_validos      TYPE abap_boolean,
      "! Descrição técnica do erro de validação, quando houver.
      erro               TYPE string,
      "! Status final da tentativa de pagamento (autorizado, recusado, etc.).
      status             TYPE zif_pc_constants=>ty_status_pagamento,
      "! Método de pagamento efetivamente processado.
      metodo             TYPE zif_pc_constants=>ty_metodo_pagamento,
      "! Bandeira identificada para o cartão informado (ex.: VISA, Mastercard).
      bandeira           TYPE string,
      "! Últimos 4 dígitos do cartão para exibição segura.
      ultimos4           TYPE string,
      "! Número do cartão mascarado para retorno ao consumidor da API.
      cartao_mascarado   TYPE string,
      "! Código de autorização retornado pela simulação de adquirência.
      codigo_autorizacao TYPE string,
      "! Mensagem amigável com o resultado do processamento.
      mensagem           TYPE string,
    END OF ty_resultado.

  TYPES:
    "! Erro de validação de um campo da entrada do pagamento
    BEGIN OF ty_erro,
      "! Nome do campo, como exibido ao usuário
      campo       TYPE string,
      "! <strong>abap_true</strong>: campo não informado; <strong>abap_false</strong>: valor inválido
      obrigatorio TYPE abap_boolean,
      "! Descrição do erro de formato (vazia quando o campo não foi informado)
      mensagem    TYPE string,
    END OF ty_erro,
    "! Erros de validação, um por campo
    tt_erros TYPE STANDARD TABLE OF ty_erro WITH EMPTY KEY.

  "! Valida todos os campos da entrada, sem simular o pagamento. Usado pelo
  "! precheck da action SimularPagamento (todos os erros de uma vez) e pela
  "! própria simulação (primeiro erro).
  "! @parameter is_entrada | Dados de entrada do pagamento (método, cartão, validade e CVV).
  "! @parameter iv_data_referencia | Data de referência para a validade do cartão (padrão: hoje).
  "! @parameter rt_erros | Erros encontrados, na ordem dos campos; vazia se a entrada é válida.
  CLASS-METHODS validar
    IMPORTING is_entrada         TYPE ty_entrada
              iv_data_referencia TYPE d OPTIONAL
    RETURNING VALUE(rt_erros)    TYPE tt_erros.

  "! Executa a simulação de pagamento com base nos dados informados.
  "! @parameter is_entrada | Dados de entrada do pagamento (método, cartão, validade e CVV).
  "! @parameter iv_data_referencia | Data de referência para controle de validade e regras da simulação.
  "! @parameter rs_resultado | Resultado da simulação com status, dados mascarados e mensagens.
  CLASS-METHODS simular
    IMPORTING is_entrada          TYPE ty_entrada
              iv_data_referencia  TYPE d OPTIONAL
    RETURNING VALUE(rs_resultado) TYPE ty_resultado.

ENDINTERFACE.