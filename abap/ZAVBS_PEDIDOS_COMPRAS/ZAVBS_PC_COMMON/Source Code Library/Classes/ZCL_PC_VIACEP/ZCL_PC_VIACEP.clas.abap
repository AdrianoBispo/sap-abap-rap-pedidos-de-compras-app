"! <h1>Classe que implementa a Consulta ViaCEP</h1>
"!
"! <ul>
"!  <li><strong>Ambiente Trial:</strong> Usa {@link cl_http_destination_provider.METH:create_by_url} (URL pública).</li>
"!  <li>
"!    <strong>Ambiemte de Produção:</strong> substituir por {@link cl_http_destination_provider.METH:create_by_comm_arrangement}
"!    (Communication Scenario + Outbound Service HTTP + Communication Arrangement).
"!  </li>
"! </ul>
"!
"! <p>
"!  <strong>IMPORTANTE (ABAP Cloud):</strong> o parse do JSON é feito com expressões regulares
"!  porque <strong>/UI2/CL_JSON</strong> não possui contrato de liberação C1 (e não existe no
"!  SAP BTP ABAP Environment). O JSON do ViaCEP é plano, o que torna a extração
"!  campo a campo segura.
"! </p>
"!
"! Uma alternativa para substituir o parse do JSON feito com expressões regulares seria por meio da utilização do: <br/>
"! <strong><em>{@link xco_cp_json}=>data->from_string( lv_json )->write_to( REF #( ls_endereco ) ).</em></strong>
"!
"! <p>Constantes, tipos e métodos públicos são definidos na interface <strong>{@link ZIF_PC_VIACEP}</strong></p>
CLASS zcl_pc_viacep DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_pc_viacep.
    ALIASES consultar FOR zif_pc_viacep~consultar.

  PRIVATE SECTION.
    TYPES:
      "! Estrutura interna do cache de respostas do ViaCEP.
      "! Armazena o CEP consultado e o resultado já processado para reutilização.
      BEGIN OF ty_cache,
        cep       TYPE string,
        resultado TYPE zif_pc_viacep=>ty_resultado,
      END OF ty_cache.

    CONSTANTS:
      "! URL base da API pública do ViaCEP.
      "! Em ambiente de produção, o destino HTTP deve ser migrado para
      "! um Communication Arrangement / outbound service configurado.
      c_url_base  TYPE string VALUE `https://viacep.com.br/ws/`,

      "! Limite máximo do cache interno de respostas consultadas.
      "! Mantém o número de registros em um teto para evitar uso excessivo de memória.
      c_max_cache TYPE i      VALUE 100.

    "! Cache de consultas recentes para evitar chamadas repetidas ao mesmo serviço.
    "! O limite evita crescimento ilimitado de memória em execução longa.
    CLASS-DATA gt_cache TYPE STANDARD TABLE OF ty_cache WITH EMPTY KEY.

    "! Realiza a chamada HTTP ao ViaCEP para um CEP informado.
    "! Retorna a estrutura de resultado padronizada pela interface do contrato.
    CLASS-METHODS chamar_servico
      IMPORTING iv_cep              TYPE string
      RETURNING VALUE(rs_resultado) TYPE zif_pc_viacep=>ty_resultado.

    "! Extrai um campo de um JSON plano ("campo": "valor" ou "campo": literal).
    "! A implementação utiliza expressão regular porque o JSON do ViaCEP
    "! é simples e evita dependência de parser JSON não disponível na plataforma.
    CLASS-METHODS extrair_campo
      IMPORTING iv_json         TYPE string
                iv_campo        TYPE string
      RETURNING VALUE(rv_valor) TYPE string.
ENDCLASS.


CLASS zcl_pc_viacep IMPLEMENTATION.

  METHOD zif_pc_viacep~consultar.
    DATA(lv_cep) = zcl_pc_util=>somente_digitos( iv_cep ).

    IF strlen( lv_cep ) <> 8.
      rs_resultado-valido = abap_false.
      RETURN.
    ENDIF.

    READ TABLE gt_cache INTO DATA(ls_cache) WITH KEY cep = lv_cep.

    IF sy-subrc = 0.
      rs_resultado = ls_cache-resultado.
      RETURN.
    ENDIF.

    rs_resultado = chamar_servico( lv_cep ).

    " Cache apenas para respostas definitivas (indisponibilidade não é cacheada)
    IF rs_resultado-indisponivel = abap_false.
      IF lines( gt_cache ) >= c_max_cache.
        DELETE gt_cache INDEX 1.
      ENDIF.

      APPEND VALUE #( cep = lv_cep resultado = rs_resultado ) TO gt_cache.
    ENDIF.
  ENDMETHOD.


  METHOD chamar_servico.
    DATA lv_status TYPE i.
    DATA lv_json   TYPE string.
    DATA lo_cliente TYPE REF TO if_web_http_client.

    TRY.
        DATA(lo_destino) = cl_http_destination_provider=>create_by_url( i_url = |{ c_url_base }{ iv_cep }/json/| ).

        lo_cliente = cl_web_http_client_manager=>create_by_http_destination( lo_destino ).

        lo_cliente->get_http_request( )->set_header_field( i_name  = `Accept`
                                                           i_value = `application/json` ).

        DATA(lo_resposta) = lo_cliente->execute( if_web_http_client=>get ).

        lv_status = lo_resposta->get_status( )-code.
        lv_json   = lo_resposta->get_text( ).

      CATCH cx_http_dest_provider_error cx_web_http_client_error cx_web_message_error.
        rs_resultado-indisponivel = abap_true.
    ENDTRY.

    " Fecha o cliente também em caso de erro (evita conexões abertas)
    IF lo_cliente IS BOUND.
      TRY.
          lo_cliente->close( ).
        CATCH cx_web_http_client_error.
          " conexão já encerrada
      ENDTRY.
    ENDIF.

    IF rs_resultado-indisponivel = abap_true.
      RETURN.
    ENDIF.

    CASE lv_status.

      WHEN 200.
        " segue para o parse

      WHEN 400 OR 404.
        " Formato inválido ou CEP inexistente segundo o ViaCEP
        rs_resultado-valido = abap_false.
        RETURN.

      WHEN OTHERS.
        " API ViaCEP Indisponivel
        rs_resultado-indisponivel = abap_true.
        RETURN.
    ENDCASE.

    rs_resultado-endereco = VALUE #(

      cep         = extrair_campo( iv_json = lv_json iv_campo = `cep` )
      logradouro  = extrair_campo( iv_json = lv_json iv_campo = `logradouro` )
      complemento = extrair_campo( iv_json = lv_json iv_campo = `complemento` )
      bairro      = extrair_campo( iv_json = lv_json iv_campo = `bairro` )
      localidade  = extrair_campo( iv_json = lv_json iv_campo = `localidade` )
      uf          = extrair_campo( iv_json = lv_json iv_campo = `uf` )
      estado      = extrair_campo( iv_json = lv_json iv_campo = `estado` )
      erro        = extrair_campo( iv_json = lv_json iv_campo = `erro` )

      ).

    " CEP inexistente: {"erro": true} ou {"erro": "true"}
    IF rs_resultado-endereco-erro IS NOT INITIAL
       OR rs_resultado-endereco-localidade IS INITIAL.

      rs_resultado-valido = abap_false.
      RETURN.
    ENDIF.

    rs_resultado-valido    = abap_true.
    rs_resultado-cep_geral = xsdbool( rs_resultado-endereco-logradouro IS INITIAL ).
  ENDMETHOD.


  METHOD extrair_campo.
    " Literais com backtick não interpretam escapes: o PCRE vai íntegro
    DATA(lv_pattern) = `"` && iv_campo && `"\s*:\s*(?:"([^"]*)"|([a-zA-Z]+))`.

    FIND PCRE lv_pattern IN iv_json SUBMATCHES DATA(lv_texto) DATA(lv_literal).

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    rv_valor = COND #( WHEN lv_texto IS NOT INITIAL THEN lv_texto
                       WHEN lv_literal = `null`     THEN ``
                       ELSE lv_literal ).
  ENDMETHOD.

ENDCLASS.
