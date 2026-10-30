"! <h1>Classe que implementa pagamento simulado com cartão</h1>
"!
"! Classe que implementa a lógica de simular pagamento ao executar a action
"! "SimularPagamento" declarada no Behavior Definition <strong>ZR_PC_PEDIDO:</strong>
"! Nenhum dado sensível sai deste método: número completo, validade e
"! CVV são usados apenas em memória e limpos ao final.<br/><br/>
"!
"! <strong>Regras de simulação:</strong>
"! <ul>
"!  <li>
"!    Cartão com número iniciado em <strong>4 = VISA</strong> e número iniciado com <strong>5 = MASTERCARD</strong>
"!  </li>
"! <li>Cartão informado com <strong>CVV = 000 => pagamento RECUSADO</strong></li>
"! <li>Demais combinações são válidas e o pagamento é APROVADO.</li>
"! </ul>
"!
"! <p>Constantes, tipos e métodos públicos são definidos na interface <strong>{@link ZIF_PC_PAGAMENTO_SIM}</strong></p>
CLASS zcl_pc_pagamento_sim DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_pc_pagamento_sim.
    ALIASES simular FOR zif_pc_pagamento_sim~simular.
    ALIASES validar FOR zif_pc_pagamento_sim~validar.
ENDCLASS.


CLASS zcl_pc_pagamento_sim IMPLEMENTATION.

  METHOD zif_pc_pagamento_sim~validar.

    DATA(lv_hoje) = COND d( WHEN iv_data_referencia IS INITIAL
                            THEN cl_abap_context_info=>get_system_date( )
                            ELSE iv_data_referencia ).

    DATA(lv_metodo)   = to_upper( condense( is_entrada-metodo ) ).
    DATA(lv_numero)   = zcl_pc_util=>somente_digitos( is_entrada-numero ).
    DATA(lv_validade) = zcl_pc_util=>somente_digitos( is_entrada-validade ).
    DATA(lv_cvv)      = zcl_pc_util=>somente_digitos( is_entrada-cvv ).

    " Cada campo é avaliado de forma independente: todos os erros de uma vez
    IF lv_metodo IS INITIAL.
      APPEND VALUE #( campo = `Método de pagamento` obrigatorio = abap_true ) TO rt_erros.
    ELSEIF lv_metodo <> zif_pc_constants=>c_metodo_pagamento-credito
       AND lv_metodo <> zif_pc_constants=>c_metodo_pagamento-debito.
      APPEND VALUE #( campo = `Método de pagamento` mensagem = `método de pagamento inválido` ) TO rt_erros.
    ENDIF.

    IF lv_numero IS INITIAL.
      APPEND VALUE #( campo = `Número do cartão` obrigatorio = abap_true ) TO rt_erros.
    ELSEIF strlen( lv_numero ) < 13 OR strlen( lv_numero ) > 19.
      APPEND VALUE #( campo = `Número do cartão` mensagem = `número do cartão deve ter de 13 a 19 dígitos` ) TO rt_erros.
    ENDIF.

    IF lv_validade IS INITIAL.
      APPEND VALUE #( campo = `Validade (MM/AA)` obrigatorio = abap_true ) TO rt_erros.
    ELSEIF strlen( lv_validade ) <> 4.
      APPEND VALUE #( campo = `Validade (MM/AA)` mensagem = `validade deve estar no formato MM/AA` ) TO rt_erros.
    ELSE.
      DATA(lv_mes)       = CONV i( lv_validade(2) ).
      DATA(lv_ano)       = 2000 + CONV i( lv_validade+2(2) ).
      DATA(lv_ano_atual) = CONV i( lv_hoje(4) ).
      DATA(lv_mes_atual) = CONV i( lv_hoje+4(2) ).

      IF lv_mes < 1 OR lv_mes > 12.
        APPEND VALUE #( campo = `Validade (MM/AA)` mensagem = `mês de validade inválido` ) TO rt_erros.
      ELSEIF lv_ano < lv_ano_atual OR ( lv_ano = lv_ano_atual AND lv_mes < lv_mes_atual ).
        APPEND VALUE #( campo = `Validade (MM/AA)` mensagem = `cartão expirado` ) TO rt_erros.
      ENDIF.
    ENDIF.

    IF lv_cvv IS INITIAL.
      APPEND VALUE #( campo = `CVV` obrigatorio = abap_true ) TO rt_erros.
    ELSEIF strlen( lv_cvv ) < 3 OR strlen( lv_cvv ) > 4.
      APPEND VALUE #( campo = `CVV` mensagem = `CVV deve ter 3 ou 4 dígitos` ) TO rt_erros.
    ENDIF.

    " Dados sensíveis descartados
    CLEAR: lv_numero, lv_validade, lv_cvv.
  ENDMETHOD.


  METHOD zif_pc_pagamento_sim~simular.

*---------------------------------------------------------------------*
    " 1) Validação dos formatos dos dados de entrada (primeiro erro)
*---------------------------------------------------------------------*

    DATA(lt_erros) = validar( is_entrada         = is_entrada
                              iv_data_referencia = iv_data_referencia ).

    IF lt_erros IS NOT INITIAL.
      DATA(ls_erro) = lt_erros[ 1 ].
      rs_resultado-dados_validos = abap_false.
      rs_resultado-erro = COND #( WHEN ls_erro-obrigatorio = abap_true
                                  THEN |{ to_lower( ls_erro-campo ) } não informado|
                                  ELSE ls_erro-mensagem ).
      RETURN.
    ENDIF.

    rs_resultado-dados_validos = abap_true.

*---------------------------------------------------------------------*
    " 2) Tratamento dos dados de entrada
*---------------------------------------------------------------------*

    DATA(lv_metodo) = to_upper( condense( is_entrada-metodo ) ).
    DATA(lv_numero) = zcl_pc_util=>somente_digitos( is_entrada-numero ).
    DATA(lv_cvv)    = zcl_pc_util=>somente_digitos( is_entrada-cvv ).


*---------------------------------------------------------------------*
    " 3) Dados seguros que podem ser persistidos
*---------------------------------------------------------------------*

    rs_resultado-metodo   = lv_metodo.
    rs_resultado-bandeira = SWITCH #( lv_numero(1)
                                      WHEN '4' THEN `VISA`
                                      WHEN '5' THEN `MASTERCARD`
                                      ELSE `OUTRA` ).

    DATA(lv_pos)                  = strlen( lv_numero ) - 4.
    rs_resultado-ultimos4         = lv_numero+lv_pos(4).
    rs_resultado-cartao_mascarado = |**** **** **** { rs_resultado-ultimos4 }|.

    IF lv_cvv = `000`.
      rs_resultado-status   = zif_pc_constants=>c_status_pagamento-recusado.
      rs_resultado-mensagem = `Pagamento recusado pela operadora (simulação).`.

    ELSE.


      DATA(lo_random) = cl_abap_random_int=>create( seed = cl_abap_random=>seed( )
                                                    min  = 100000
                                                    max  = 999999 ).

      " 4) Resultado da simulação ------------------------------------------
      rs_resultado-status             = zif_pc_constants=>c_status_pagamento-aprovado.
      rs_resultado-codigo_autorizacao = |SIM{ lo_random->get_next( ) }|.
      rs_resultado-mensagem           = |Pagamento aprovado (simulação) - { rs_resultado-bandeira }.|.
    ENDIF.

    " 5) Dados sensíveis descartados
    CLEAR: lv_numero, lv_cvv.
  ENDMETHOD.

ENDCLASS.