"! <p class="shorttext synchronized">Pedidos de Compras - Query provider da consulta de CEP</p>
"! Implementa a custom entity ZI_PC_CEP_LOOKUP (entity set CepLookUp do
"! serviço ZUI_PC_CLIENTES). É o único ponto em que a app de Clientes chama o
"! ViaCEP: a UI lê esta entidade e repassa a linha à ação AplicarDadosCep, que
"! grava o resultado no draft do Endereço. O BO não faz I/O remoto.
"!
"! Nunca falha por CEP inválido ou ViaCEP fora do ar: devolve uma linha com
"! Status I / X e o texto da Message Class ZPC_MSG em Message.
CLASS zcl_pc_cep_lookup_provider DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES tt_resultado TYPE STANDARD TABLE OF zi_pc_cep_lookup WITH EMPTY KEY.

    "! Consulta o ViaCEP e converte o retorno em uma linha da custom entity.
    CLASS-METHODS consultar
      IMPORTING iv_cep              TYPE string
      RETURNING VALUE(rs_resultado) TYPE zi_pc_cep_lookup.

    "! Texto da Message Class ZPC_MSG: fonte única entre provider, BO e UI.
    CLASS-METHODS texto
      IMPORTING textid          LIKE if_t100_message=>t100key
      RETURNING VALUE(rv_texto) TYPE string.
ENDCLASS.



CLASS zcl_pc_cep_lookup_provider IMPLEMENTATION.

  METHOD if_rap_query_provider~select.
    DATA lt_resultado TYPE tt_resultado.
    DATA lt_pagina    TYPE tt_resultado.

    DATA(lv_dados)      = io_request->is_data_requested( ).
    DATA(lv_quantidade) = io_request->is_total_numb_of_rec_requested( ).

    IF lv_dados = abap_false AND lv_quantidade = abap_false.
      RETURN.
    ENDIF.

    " O runtime exige GET_PAGING quando a requisição OData tem paginação
    DATA(lo_paginacao) = io_request->get_paging( ).
    DATA(lv_tamanho)   = lo_paginacao->get_page_size( ).
    DATA(lv_offset)    = lo_paginacao->get_offset( ).

    TRY.
        DATA(lt_filtros) = io_request->get_filter( )->get_as_ranges( ).

        READ TABLE lt_filtros WITH KEY name = 'CEP' INTO DATA(ls_filtro).
        IF sy-subrc <> 0 OR ls_filtro-range IS INITIAL.
          APPEND VALUE #( Status  = zif_pc_constants=>c_status_cep-invalido
                          Message = texto( zif_pc_errors_constants=>cep_filtro_ausente ) ) TO lt_resultado.
        ELSE.
          READ TABLE ls_filtro-range INDEX 1 INTO DATA(ls_range).
          IF sy-subrc <> 0 OR ls_range-sign <> 'I' OR ls_range-option <> 'EQ'.
            APPEND VALUE #( Status  = zif_pc_constants=>c_status_cep-invalido
                            Message = texto( zif_pc_errors_constants=>cep_filtro_invalido ) ) TO lt_resultado.
          ELSE.
            " ls_range-low chega como string: normalizar ANTES de converter
            " para o campo de 8 posições, senão "01001-000" seria truncado.
            APPEND consultar( zcl_pc_util=>somente_digitos( ls_range-low ) ) TO lt_resultado.
          ENDIF.
        ENDIF.

      CATCH cx_rap_query_filter_no_range.
        APPEND VALUE #( Status  = zif_pc_constants=>c_status_cep-invalido
                        Message = texto( zif_pc_errors_constants=>cep_filtro_invalido ) ) TO lt_resultado.
    ENDTRY.

    IF lv_quantidade = abap_true.
      io_response->set_total_number_of_records( lines( lt_resultado ) ).
    ENDIF.

    IF lv_dados = abap_false.
      RETURN.
    ENDIF.

    " Page size negativo representa "sem limite"
    IF lv_tamanho < 0.
      lt_pagina = lt_resultado.
    ELSEIF lv_tamanho > 0 AND lv_offset < lines( lt_resultado ).
      DATA(lv_de)  = CONV i( lv_offset + 1 ).
      DATA(lv_ate) = CONV i( nmin( val1 = lv_offset + lv_tamanho
                                   val2 = lines( lt_resultado ) ) ).
      LOOP AT lt_resultado INTO DATA(ls_linha) FROM lv_de TO lv_ate.
        APPEND ls_linha TO lt_pagina.
      ENDLOOP.
    ENDIF.

    io_response->set_data( lt_pagina ).
  ENDMETHOD.


  METHOD consultar.
    rs_resultado-Cep = iv_cep.

    IF strlen( iv_cep ) <> 8.
      rs_resultado-Status  = zif_pc_constants=>c_status_cep-invalido.
      rs_resultado-Message = texto( zif_pc_errors_constants=>cep_invalido ).
      RETURN.
    ENDIF.

    DATA(ls_viacep) = zcl_pc_viacep=>consultar( iv_cep ).

    IF ls_viacep-indisponivel = abap_true.
      rs_resultado-Status  = zif_pc_constants=>c_status_cep-indisponivel.
      rs_resultado-Message = texto( zif_pc_errors_constants=>cep_indisponivel ).
      RETURN.
    ENDIF.

    IF ls_viacep-valido = abap_false.
      rs_resultado-Status  = zif_pc_constants=>c_status_cep-invalido.
      rs_resultado-Message = texto( zif_pc_errors_constants=>cep_invalido ).
      RETURN.
    ENDIF.

    rs_resultado-Logradouro  = ls_viacep-endereco-logradouro.
    rs_resultado-Complemento = ls_viacep-endereco-complemento.
    rs_resultado-Bairro      = ls_viacep-endereco-bairro.
    rs_resultado-Cidade      = ls_viacep-endereco-localidade.
    rs_resultado-Uf          = ls_viacep-endereco-uf.
    " Respostas antigas do ViaCEP não trazem "estado": cai para a UF
    rs_resultado-Estado      = COND #( WHEN ls_viacep-endereco-estado IS NOT INITIAL
                                       THEN ls_viacep-endereco-estado
                                       ELSE ls_viacep-endereco-uf ).
    rs_resultado-CepGeral    = ls_viacep-cep_geral.
    rs_resultado-Status      = zif_pc_constants=>c_status_cep-validado.
    rs_resultado-Message     = texto( zif_pc_errors_constants=>cep_consultado ).
  ENDMETHOD.


  METHOD texto.
    rv_texto = NEW zcx_pc_msg( textid = textid )->get_text( ).
  ENDMETHOD.

ENDCLASS.
