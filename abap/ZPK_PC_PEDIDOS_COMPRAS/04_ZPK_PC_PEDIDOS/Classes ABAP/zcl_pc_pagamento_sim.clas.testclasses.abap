*"* Test Classes da classe ZCL_PC_PAGAMENTO_SIM
*"* A data de referência é injetada (iv_data_referencia), o que torna os
*"* testes determinísticos e independentes do relógio do sistema.

CLASS ltcl_pagamento DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CONSTANTS c_hoje       TYPE d      VALUE '20260320'.
    CONSTANTS c_visa       TYPE string VALUE `4111111111111111`.
    CONSTANTS c_mastercard TYPE string VALUE `5555555555554444`.

    METHODS simular
      IMPORTING iv_numero           TYPE string DEFAULT `4111111111111111`
                iv_validade         TYPE string DEFAULT `12/30`
                iv_cvv              TYPE string DEFAULT `123`
                iv_metodo           TYPE string DEFAULT `CARTAO_CREDITO`
      RETURNING VALUE(rs_resultado) TYPE zcl_pc_pagamento_sim=>ty_resultado.

    METHODS credito_aprovado_visa      FOR TESTING.
    METHODS debito_aprovado            FOR TESTING.
    METHODS bandeira_mastercard        FOR TESTING.
    METHODS bandeira_outra             FOR TESTING.
    METHODS cvv_000_recusa             FOR TESTING.
    METHODS numero_com_mascara         FOR TESTING.
    METHODS numero_curto_invalido      FOR TESTING.
    METHODS numero_longo_invalido      FOR TESTING.
    METHODS cvv_curto_invalido         FOR TESTING.
    METHODS metodo_invalido            FOR TESTING.
    METHODS mes_validade_invalido      FOR TESTING.
    METHODS cartao_expirado            FOR TESTING.
    METHODS validade_mes_corrente_ok   FOR TESTING.
    METHODS nao_expoe_numero_completo  FOR TESTING.
ENDCLASS.


CLASS ltcl_pagamento IMPLEMENTATION.

  METHOD simular.
    rs_resultado = zcl_pc_pagamento_sim=>simular(
                     is_entrada         = VALUE #( metodo   = iv_metodo
                                                   numero   = iv_numero
                                                   validade = iv_validade
                                                   cvv      = iv_cvv )
                     iv_data_referencia = c_hoje ).
  ENDMETHOD.


  METHOD credito_aprovado_visa.
    DATA(ls_resultado) = simular( ).

    cl_abap_unit_assert=>assert_equals( act = ls_resultado-dados_validos
                                        exp = abap_true
                                        msg = 'Dados completos e válidos' ).
    cl_abap_unit_assert=>assert_equals( act = ls_resultado-status
                                        exp = zif_pc_constants=>c_status_pagamento-aprovado
                                        msg = 'CVV diferente de 000 deve aprovar' ).
    cl_abap_unit_assert=>assert_equals( act = ls_resultado-bandeira
                                        exp = `VISA`
                                        msg = 'Número iniciado por 4 => VISA' ).
    cl_abap_unit_assert=>assert_equals( act = ls_resultado-ultimos4
                                        exp = `1111`
                                        msg = 'Somente os quatro últimos dígitos' ).
    cl_abap_unit_assert=>assert_equals( act = ls_resultado-cartao_mascarado
                                        exp = `**** **** **** 1111`
                                        msg = 'Máscara padrão do cartão' ).
    cl_abap_unit_assert=>assert_not_initial( act = ls_resultado-codigo_autorizacao
                                             msg = 'Aprovação gera código de autorização' ).
  ENDMETHOD.


  METHOD debito_aprovado.
    DATA(ls_resultado) = simular( iv_metodo = `CARTAO_DEBITO` ).

    cl_abap_unit_assert=>assert_equals( act = ls_resultado-status
                                        exp = zif_pc_constants=>c_status_pagamento-aprovado
                                        msg = 'Débito também é método aceito' ).
    cl_abap_unit_assert=>assert_equals( act = ls_resultado-metodo
                                        exp = zif_pc_constants=>c_metodo_pagamento-debito
                                        msg = 'Método deve ser devolvido normalizado' ).
  ENDMETHOD.


  METHOD bandeira_mastercard.
    cl_abap_unit_assert=>assert_equals( act = simular( iv_numero = c_mastercard )-bandeira
                                        exp = `MASTERCARD`
                                        msg = 'Número iniciado por 5 => MASTERCARD' ).
  ENDMETHOD.


  METHOD bandeira_outra.
    cl_abap_unit_assert=>assert_equals( act = simular( iv_numero = `6011111111111117` )-bandeira
                                        exp = `OUTRA`
                                        msg = 'Demais prefixos => OUTRA' ).
  ENDMETHOD.


  METHOD cvv_000_recusa.
    DATA(ls_resultado) = simular( iv_cvv = `000` ).

    cl_abap_unit_assert=>assert_equals( act = ls_resultado-dados_validos
                                        exp = abap_true
                                        msg = 'Recusa não é erro de dados' ).
    cl_abap_unit_assert=>assert_equals( act = ls_resultado-status
                                        exp = zif_pc_constants=>c_status_pagamento-recusado
                                        msg = 'CVV 000 simula recusa' ).
    cl_abap_unit_assert=>assert_initial( act = ls_resultado-codigo_autorizacao
                                         msg = 'Recusa não gera código de autorização' ).
    cl_abap_unit_assert=>assert_not_initial( act = ls_resultado-mensagem
                                             msg = 'Recusa deve explicar o resultado' ).
  ENDMETHOD.


  METHOD numero_com_mascara.
    DATA(ls_resultado) = simular( iv_numero = `4111 1111 1111 1111` ).

    cl_abap_unit_assert=>assert_equals( act = ls_resultado-dados_validos
                                        exp = abap_true
                                        msg = 'Espaços no número devem ser ignorados' ).
    cl_abap_unit_assert=>assert_equals( act = ls_resultado-ultimos4
                                        exp = `1111`
                                        msg = 'Últimos dígitos após normalização' ).
  ENDMETHOD.


  METHOD numero_curto_invalido.
    DATA(ls_resultado) = simular( iv_numero = `411111111111` ).

    cl_abap_unit_assert=>assert_equals( act = ls_resultado-dados_validos
                                        exp = abap_false
                                        msg = 'Menos de 13 dígitos é dado inválido' ).
    cl_abap_unit_assert=>assert_initial( act = ls_resultado-status
                                         msg = 'Dado inválido não produz status de pagamento' ).
  ENDMETHOD.


  METHOD numero_longo_invalido.
    cl_abap_unit_assert=>assert_equals( act = simular( iv_numero = `41111111111111111111` )-dados_validos
                                        exp = abap_false
                                        msg = 'Mais de 19 dígitos é dado inválido' ).
  ENDMETHOD.


  METHOD cvv_curto_invalido.
    cl_abap_unit_assert=>assert_equals( act = simular( iv_cvv = `12` )-dados_validos
                                        exp = abap_false
                                        msg = 'CVV precisa de 3 ou 4 dígitos' ).
  ENDMETHOD.


  METHOD metodo_invalido.
    cl_abap_unit_assert=>assert_equals( act = simular( iv_metodo = `PIX` )-dados_validos
                                        exp = abap_false
                                        msg = 'Apenas cartão de crédito ou débito' ).
  ENDMETHOD.


  METHOD mes_validade_invalido.
    cl_abap_unit_assert=>assert_equals( act = simular( iv_validade = `13/30` )-dados_validos
                                        exp = abap_false
                                        msg = 'Mês 13 não existe' ).
  ENDMETHOD.


  METHOD cartao_expirado.
    DATA(ls_resultado) = simular( iv_validade = `02/26` ).

    cl_abap_unit_assert=>assert_equals( act = ls_resultado-dados_validos
                                        exp = abap_false
                                        msg = 'Validade anterior à data de referência' ).
    cl_abap_unit_assert=>assert_not_initial( act = ls_resultado-erro
                                             msg = 'O motivo do erro deve ser informado' ).
  ENDMETHOD.


  METHOD validade_mes_corrente_ok.
    " Data de referência 20/03/2026: cartão válido até 03/26 ainda vale
    cl_abap_unit_assert=>assert_equals( act = simular( iv_validade = `03/26` )-dados_validos
                                        exp = abap_true
                                        msg = 'O cartão vale até o fim do mês de validade' ).
  ENDMETHOD.


  METHOD nao_expoe_numero_completo.
    DATA(ls_resultado) = simular( ).

    cl_abap_unit_assert=>assert_equals(
      act = xsdbool( contains( val = ls_resultado-cartao_mascarado sub = c_visa )
                  OR contains( val = ls_resultado-codigo_autorizacao sub = c_visa )
                  OR contains( val = ls_resultado-mensagem sub = c_visa ) )
      exp = abap_false
      msg = 'Nenhum campo persistível pode conter o número completo do cartão' ).
  ENDMETHOD.

ENDCLASS.
