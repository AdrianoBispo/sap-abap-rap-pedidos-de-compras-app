"! <p class="shorttext synchronized">Pedidos de Compras - Consulta de CEP (ViaCEP)</p>
"! Trial: usa cl_http_destination_provider=>create_by_url (URL pública).
"! Produção: substituir por create_by_comm_arrangement (Communication
"! Scenario + Outbound Service HTTP + Communication Arrangement).
"!
"! IMPORTANTE (ABAP Cloud): o parse do JSON é feito com expressões regulares
"! porque /UI2/CL_JSON não possui contrato de liberação C1 (e não existe no
"! SAP BTP ABAP Environment). O JSON do ViaCEP é plano, o que torna a extração
"! campo a campo segura. Alternativa liberada, se disponível no seu release:
"!   xco_cp_json=>data->from_string( lv_json )->write_to( REF #( ls_endereco ) ).
CLASS zcl_pc_viacep DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_endereco,
        cep         TYPE string,
        logradouro  TYPE string,
        complemento TYPE string,
        bairro      TYPE string,
        localidade  TYPE string,
        uf          TYPE string,
        estado      TYPE string,
        erro        TYPE string,
      END OF ty_endereco.

    TYPES:
      BEGIN OF ty_resultado,
        "! CEP existe e dados foram retornados
        valido       TYPE abap_boolean,
        "! Serviço indisponível (timeout, erro HTTP 5xx, rede)
        indisponivel TYPE abap_boolean,
        "! CEP geral de município: ViaCEP não retorna logradouro/bairro
        cep_geral    TYPE abap_boolean,
        endereco     TYPE ty_endereco,
      END OF ty_resultado.

    CONSTANTS c_url_base TYPE string VALUE `https://viacep.com.br/ws/`.

    "! Consulta o CEP (8 dígitos). Resultados definitivos ficam em cache por
    "! sessão (limitado a c_max_cache entradas) para evitar chamadas repetidas.
    CLASS-METHODS consultar
      IMPORTING iv_cep              TYPE csequence
      RETURNING VALUE(rs_resultado) TYPE ty_resultado.

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_cache,
        cep       TYPE string,
        resultado TYPE ty_resultado,
      END OF ty_cache.

    CONSTANTS c_max_cache TYPE i VALUE 100.

    CLASS-DATA gt_cache TYPE STANDARD TABLE OF ty_cache WITH EMPTY KEY.

    CLASS-METHODS chamar_servico
      IMPORTING iv_cep              TYPE string
      RETURNING VALUE(rs_resultado) TYPE ty_resultado.

    "! Extrai um campo de um JSON plano ("campo": "valor" ou "campo": literal).
    CLASS-METHODS extrair_campo
      IMPORTING iv_json         TYPE string
                iv_campo        TYPE string
      RETURNING VALUE(rv_valor) TYPE string.
ENDCLASS.



CLASS zcl_pc_viacep IMPLEMENTATION.

  METHOD consultar.
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
        DATA(lo_destino) = cl_http_destination_provider=>create_by_url(
                             i_url = |{ c_url_base }{ iv_cep }/json/| ).

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
      erro        = extrair_campo( iv_json = lv_json iv_campo = `erro` ) ).

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
