*"* Test Classes da classe ZCL_PC_PAGAMENTO_SIM
*"* A data de referência é injetada (iv_data_referencia), o que torna os
*"* testes determinísticos e independentes do relógio do sistema.

"! Testes unitários de {@link ZCL_PC_PAGAMENTO_SIM}: regras da simulação
"! ({@link ZCL_PC_PAGAMENTO_SIM.METH:simular}) e validação da entrada
"! ({@link ZCL_PC_PAGAMENTO_SIM.METH:validar}).
CLASS ltcl_pagamento DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    "! Data de referência fixa dos testes (validade do cartão)
    CONSTANTS c_hoje       TYPE d      VALUE '20260320'.
    "! Cartão VISA de teste
    CONSTANTS c_visa       TYPE string VALUE `4111111111111111`.
    "! Cartão Mastercard de teste
    CONSTANTS c_mastercard TYPE string VALUE `5555555555554444`.

    "! Simula com a data de referência {@link .DATA:c_hoje}; os valores
    "! padrão formam um pagamento válido no crédito.
    METHODS simular
      IMPORTING iv_numero           TYPE string DEFAULT `4111111111111111`
                iv_validade         TYPE string DEFAULT `12/30`
                iv_cvv              TYPE string DEFAULT `123`
                iv_metodo           TYPE string DEFAULT `CARTAO_CREDITO`
      RETURNING VALUE(rs_resultado) TYPE zif_pc_pagamento_sim=>ty_resultado.

    "! Crédito com dados válidos é aprovado, bandeira VISA.
    METHODS credito_aprovado_visa      FOR TESTING.
    "! Débito com dados válidos é aprovado.
    METHODS debito_aprovado            FOR TESTING.
    "! Número iniciado em 5 é Mastercard.
    METHODS bandeira_mastercard        FOR TESTING.
    "! Outros prefixos resultam na bandeira OUTRA.
    METHODS bandeira_outra             FOR TESTING.
    "! CVV 000 simula recusa da operadora (não é erro de dados).
    METHODS cvv_000_recusa             FOR TESTING.
    "! Número com espaços/traços é aceito (só dígitos contam).
    METHODS numero_com_mascara         FOR TESTING.
    "! Número com menos de 13 dígitos é inválido.
    METHODS numero_curto_invalido      FOR TESTING.
    "! Número com mais de 19 dígitos é inválido.
    METHODS numero_longo_invalido      FOR TESTING.
    "! CVV com menos de 3 dígitos é inválido.
    METHODS cvv_curto_invalido         FOR TESTING.
    "! Método diferente de crédito/débito é inválido.
    METHODS metodo_invalido            FOR TESTING.
    "! Mês de validade fora de 01 a 12 é inválido.
    METHODS mes_validade_invalido      FOR TESTING.
    "! Validade anterior ao mês de referência é cartão expirado.
    METHODS cartao_expirado            FOR TESTING.
    "! O cartão vale até o fim do mês de validade.
    METHODS validade_mes_corrente_ok   FOR TESTING.
    "! Nenhum campo persistível contém o número completo do cartão.
    METHODS nao_expoe_numero_completo  FOR TESTING.
    "! {@link ZCL_PC_PAGAMENTO_SIM.METH:validar}: entrada vazia gera um erro
    "! de campo obrigatório para cada um dos 4 campos.
    METHODS validar_campos_obrigatorios FOR TESTING.
    "! {@link ZCL_PC_PAGAMENTO_SIM.METH:validar}: vários campos inválidos são
    "! devolvidos de uma vez (usado pelo precheck de SimularPagamento).
    METHODS validar_todos_os_erros      FOR TESTING.
    "! {@link ZCL_PC_PAGAMENTO_SIM.METH:validar}: entrada válida não gera erros.
    METHODS validar_entrada_valida      FOR TESTING.
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


  METHOD validar_campos_obrigatorios.
    DATA(lt_erros) = zcl_pc_pagamento_sim=>validar( is_entrada         = VALUE #( )
                                                    iv_data_referencia = c_hoje ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_erros ) exp = 4
                                        msg = 'Um erro por campo não informado' ).
    cl_abap_unit_assert=>assert_equals(
      act = REDUCE i( INIT n = 0 FOR e IN lt_erros WHERE ( obrigatorio = abap_true ) NEXT n = n + 1 )
      exp = 4
      msg = 'Todos marcados como obrigatórios' ).
  ENDMETHOD.


  METHOD validar_todos_os_erros.
    " Número curto, mês 13 e CVV curto: três erros de formato de uma vez
    DATA(lt_erros) = zcl_pc_pagamento_sim=>validar(
                       is_entrada         = VALUE #( metodo   = `CARTAO_CREDITO`
                                                     numero   = `4111`
                                                     validade = `13/30`
                                                     cvv      = `1` )
                       iv_data_referencia = c_hoje ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_erros ) exp = 3
                                        msg = 'Número, validade e CVV inválidos' ).
    cl_abap_unit_assert=>assert_equals(
      act = REDUCE i( INIT n = 0 FOR e IN lt_erros WHERE ( obrigatorio = abap_false ) NEXT n = n + 1 )
      exp = 3
      msg = 'Erros de formato, não de campo obrigatório' ).
  ENDMETHOD.


  METHOD validar_entrada_valida.
    DATA(lt_erros) = zcl_pc_pagamento_sim=>validar(
                       is_entrada         = VALUE #( metodo   = `CARTAO_DEBITO`
                                                     numero   = c_mastercard
                                                     validade = `12/30`
                                                     cvv      = `123` )
                       iv_data_referencia = c_hoje ).

    cl_abap_unit_assert=>assert_initial( act = lt_erros msg = 'Entrada válida não gera erros' ).
  ENDMETHOD.

ENDCLASS.