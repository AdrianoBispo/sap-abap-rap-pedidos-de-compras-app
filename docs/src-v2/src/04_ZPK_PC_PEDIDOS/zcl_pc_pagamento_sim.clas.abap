"! <p class="shorttext synchronized">Pedidos de Compras - Pagamento simulado com cartão</p>
"! Nenhum dado sensível sai deste método: número completo, validade e
"! CVV são usados apenas em memória e limpos ao final.
"! Regras de simulação:
"!  - número iniciado com 4 => VISA; iniciado com 5 => MASTERCARD
"!  - CVV 000 => pagamento RECUSADO
"!  - demais combinações válidas => APROVADO
CLASS zcl_pc_pagamento_sim DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
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

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_pc_pagamento_sim IMPLEMENTATION.

  METHOD simular.
    DATA(lv_hoje) = COND d( WHEN iv_data_referencia IS INITIAL
                            THEN cl_abap_context_info=>get_system_date( )
                            ELSE iv_data_referencia ).

    DATA(lv_metodo)   = to_upper( condense( is_entrada-metodo ) ).
    DATA(lv_numero)   = zcl_pc_util=>somente_digitos( is_entrada-numero ).
    DATA(lv_validade) = zcl_pc_util=>somente_digitos( is_entrada-validade ).
    DATA(lv_cvv)      = zcl_pc_util=>somente_digitos( is_entrada-cvv ).

    rs_resultado-dados_validos = abap_false.

    " 1) Validações de formato ------------------------------------------
    IF lv_metodo <> zif_pc_constants=>c_metodo_pagamento-credito
       AND lv_metodo <> zif_pc_constants=>c_metodo_pagamento-debito.
      rs_resultado-erro = `método de pagamento inválido`.
    ELSEIF strlen( lv_numero ) < 13 OR strlen( lv_numero ) > 19.
      rs_resultado-erro = `número do cartão deve ter de 13 a 19 dígitos`.
    ELSEIF strlen( lv_validade ) <> 4.
      rs_resultado-erro = `validade deve estar no formato MM/AA`.
    ELSEIF strlen( lv_cvv ) < 3 OR strlen( lv_cvv ) > 4.
      rs_resultado-erro = `CVV deve ter 3 ou 4 dígitos`.
    ELSE.
      DATA(lv_mes) = CONV i( lv_validade(2) ).
      DATA(lv_ano) = 2000 + CONV i( lv_validade+2(2) ).
      DATA(lv_ano_atual) = CONV i( lv_hoje(4) ).
      DATA(lv_mes_atual) = CONV i( lv_hoje+4(2) ).

      IF lv_mes < 1 OR lv_mes > 12.
        rs_resultado-erro = `mês de validade inválido`.
      ELSEIF lv_ano < lv_ano_atual OR ( lv_ano = lv_ano_atual AND lv_mes < lv_mes_atual ).
        rs_resultado-erro = `cartão expirado`.
      ELSE.
        rs_resultado-dados_validos = abap_true.
      ENDIF.
    ENDIF.

    IF rs_resultado-dados_validos = abap_false.
      CLEAR: lv_numero, lv_validade, lv_cvv.
      RETURN.
    ENDIF.

    " 2) Dados seguros que podem ser persistidos -------------------------
    rs_resultado-metodo   = lv_metodo.
    rs_resultado-bandeira = SWITCH #( lv_numero(1)
                                      WHEN '4' THEN `VISA`
                                      WHEN '5' THEN `MASTERCARD`
                                      ELSE `OUTRA` ).
    DATA(lv_pos) = strlen( lv_numero ) - 4.
    rs_resultado-ultimos4         = lv_numero+lv_pos(4).
    rs_resultado-cartao_mascarado = |**** **** **** { rs_resultado-ultimos4 }|.

    " 3) Resultado da simulação ------------------------------------------
    IF lv_cvv = `000`.
      rs_resultado-status   = zif_pc_constants=>c_status_pagamento-recusado.
      rs_resultado-mensagem = `Pagamento recusado pela operadora (simulação).`.
    ELSE.
      DATA(lo_random) = cl_abap_random_int=>create( seed = cl_abap_random=>seed( )
                                                    min  = 100000
                                                    max  = 999999 ).
      rs_resultado-status             = zif_pc_constants=>c_status_pagamento-aprovado.
      rs_resultado-codigo_autorizacao = |SIM{ lo_random->get_next( ) }|.
      rs_resultado-mensagem           = |Pagamento aprovado (simulação) - { rs_resultado-bandeira }.|.
    ENDIF.

    " 4) Dados sensíveis descartados
    CLEAR: lv_numero, lv_validade, lv_cvv.
  ENDMETHOD.

ENDCLASS.
